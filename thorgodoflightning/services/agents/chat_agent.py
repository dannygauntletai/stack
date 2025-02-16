from typing import Dict, Any, List
from services.agents.base_agent import BaseAgent
from services.db_service import DatabaseService
from services.vector_service import VectorService
from openai import OpenAI
from config import Config
import logging
import re
import time
import json
import pyshorteners
from langchain.callbacks.manager import tracing_v2_enabled
import os
from langsmith import traceable
from langsmith.run_helpers import get_run_tree_context
from langsmith.wrappers import wrap_openai
import langsmith as ls
from langchain_core.tracers.langchain import wait_for_all_tracers

logger = logging.getLogger(__name__)

class ChatAgent(BaseAgent):
    def __init__(self, db_service: DatabaseService):
        self.db_service = db_service
        # Wrap OpenAI client for tracing
        self.openai_client = wrap_openai(OpenAI(api_key=Config.OPENAI_API_KEY))
        self.url_shortener = pyshorteners.Shortener()
        
        # Set project and run names for chat agent
        self.project_name = "thorgodoflightning"
        self.run_name = "chat"
        
        # Explicitly set LangSmith environment variables
        os.environ["LANGCHAIN_TRACING_V2"] = "true"
        os.environ["LANGCHAIN_PROJECT"] = self.project_name
        
        # Log LangSmith configuration
        logger.info(f"Chat Agent LangSmith Configuration:")
        logger.info(f"Project Name: {self.project_name}")
        logger.info(f"Run Name: {self.run_name}")
        logger.info(f"LANGCHAIN_API_KEY set: {bool(os.getenv('LANGCHAIN_API_KEY'))}")
        logger.info(f"LANGCHAIN_TRACING_V2: {os.getenv('LANGCHAIN_TRACING_V2')}")
        
    def validate_input(self, input_data: Dict[str, Any]) -> bool:
        """Validate the input data"""
        required_fields = ['content', 'type', 'session_id']
        return all(field in input_data for field in required_fields)
        
    @traceable(project_name="thorgodoflightning", name="chat")
    async def process(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        """Process a chat message"""
        try:
            if not self.validate_input(input_data):
                raise ValueError("Invalid chat input")
            
            message_text = input_data['content']
            conversation_id = input_data.get('session_id')
            user_id = input_data.get('userId')
            
            # Get current trace context
            run_tree = ls.get_current_run_tree()
            logger.info(f"Current run tree: {run_tree}")
            logger.info(f"Run tree type: {type(run_tree)}")
            run_id = str(run_tree.id) if run_tree else None  # Convert UUID to string
            
            logger.info(f"Extracted run ID: {run_id}")
            logger.info(f"Run ID type: {type(run_id)}")
            
            # Start vector search with its own trace
            video_ids = await self._search_videos(message_text)
            
            # Generate response with context and session data
            response = await self._generate_response(message_text, video_ids, input_data)
            
            # Store in Firestore with trace ID
            message_ref = self.db_service.db.collection('messages').document()
            message_data = {
                'content': response['message']['text'],
                'type': 'text',
                'session_id': conversation_id,
                'role': 'assistant',
                'sequence': input_data.get('sequence_number', 0),
                'timestamp': time.time(),
                'senderId': 'ai',
                'feedback': {
                    'status': 'pending',
                    'run_id': run_id  # Use string UUID
                }
            }
            
            message_ref.set(message_data)  # Firebase Admin SDK's set() is already async
            
            # Wait for all traces to be submitted
            wait_for_all_tracers()
            
            # Get the final run ID after traces are submitted
            run_tree = ls.get_current_run_tree()
            run_id = str(run_tree.id) if run_tree else None
            logger.info(f"Final run ID after trace submission: {run_id}")
            
            return {
                'success': True,
                'message': {
                    'id': message_ref.id,
                    'text': response['message']['text'],
                    'videoIds': response['message']['videoIds'],
                    'isFromCurrentUser': False,
                    'timestamp': time.time(),
                    'senderId': 'ai',
                    'feedback': {
                        'status': 'pending',
                        'run_id': run_id  # Use the final run ID
                    }
                }
            }
                
        except Exception as e:
            logger.error(f"Error in process with tracing: {str(e)}", exc_info=True)
            raise

    @traceable(project_name="thorgodoflightning", name="chat_search")
    async def _search_videos(self, query: str) -> List[str]:
        """Search for relevant videos"""
        try:
            # Use enhanced search with parsed query and video namespace
            vector_results = await VectorService.search_similar(
                query,
                limit=3,
                namespace="video-metadata"  # Specify the video namespace
            )
            video_ids = [result['id'] for result in vector_results]
            return video_ids
        except Exception as e:
            logger.error(f"Error in search with tracing: {str(e)}", exc_info=True)
            raise

    @traceable(project_name="thorgodoflightning", name="chat_response")
    async def _generate_response(self, message: str, video_ids: List[str], session_data: Dict[str, Any]) -> Dict[str, str]:
        """Generate AI response"""
        try:
            # First, analyze the user's request using LLM
            analysis = await self._analyze_request(message)
            print(f"🤔 Request analysis: {analysis}")
            
            # Based on analysis, determine action and execute
            if analysis['action'] == 'recommend_videos':
                response_text = await self._handle_video_recommendation(analysis['parsed_query'])
            elif analysis['action'] == 'report_query':
                response_text = await self._handle_report_query(analysis['parsed_query'], analysis.get('requirements', {}))
            else:
                response_text = await self._handle_general_chat(message)
            
            # Return complete response structure
            return {
                'success': True,
                'message': {
                    'text': response_text,
                    'videoIds': video_ids,
                }
            }
            
        except Exception as e:
            logger.error(f"Error in generate with tracing: {str(e)}", exc_info=True)
            raise
            
    async def _analyze_request(self, content: str) -> Dict:
        """Analyze user request using LLM to determine intent and extract relevant information"""
        try:
            response = self.openai_client.chat.completions.create(
                model="gpt-4-turbo-preview",
                messages=[
                    {"role": "system", "content": """Analyze the user's request and determine:
                    1. If they're asking for video recommendations
                    2. If they're asking about previous reports or products
                    3. Extract specific requirements or preferences
                    4. Identify any constraints or filters
                    
                    Return a JSON with:
                    {
                        "action": "recommend_videos" or "report_query" or "general_chat",
                        "parsed_query": extracted search terms,
                        "requirements": {
                            "product_type": if specified,
                            "specific_product": if mentioned,
                            "attributes": specific features or benefits sought,
                            "price_range": if mentioned,
                            "concerns": specific problems to address
                        }
                    }"""},
                    {"role": "user", "content": content}
                ],
                response_format={ "type": "json_object" },
                temperature=0.7
            )
            
            return json.loads(response.choices[0].message.content)
            
        except Exception as e:
            logger.error(f"Error analyzing request: {str(e)}")
            return {"action": "general_chat", "parsed_query": content}
            
    async def _handle_video_recommendation(self, query: str) -> str:
        """Handle video recommendation requests"""
        # Use enhanced search with parsed query and video namespace
        vector_results = await VectorService.search_similar(
            query,
            limit=3,
            namespace="video-metadata"  # Specify the video namespace
        )
        
        # Handle no results case
        if not vector_results:
            return "I couldn't find any relevant videos matching your request. Try searching with different keywords or check back later when more videos are available."
        
        # Format response with video IDs
        response = "Here are some relevant videos:\n\n"
        for result in vector_results:
            response += f"  Video ID: {result['id']}\n\n"
            
        return response
        
    async def _handle_general_chat(self, content: str) -> str:
        """Handle general chat interactions"""
        chat_response = self.openai_client.chat.completions.create(
            model="gpt-4-turbo-preview",
            messages=[
                {"role": "system", "content": "You are a helpful health and wellness assistant."},
                {"role": "user", "content": content}
            ],
            temperature=0.7,
            max_tokens=500
        )
        return chat_response.choices[0].message.content

    async def _filter_results_with_llm(self, query: str, vector_results: List[Dict]) -> List[Dict]:
        """Filter vector results using LLM to determine relevance"""
        try:
            filtered_results = []
            
            for result in vector_results:
                metadata = result.get('metadata', {})
                product_context = {
                    'title': metadata.get('productTitle', ''),
                    'summary': metadata.get('summary', ''),
                    'score': result.get('score', 0)
                }
                
                response = self.openai_client.chat.completions.create(
                    model="gpt-3.5-turbo",
                    messages=[
                        {"role": "system", "content": """You are a relevance filtering expert.
                        Evaluate if the product is truly relevant to the user's query.
                        Return ONLY a JSON object with:
                        {
                            "is_relevant": true/false,
                            "relevance_score": 0-1 (float),
                            "reason": "brief explanation"
                        }"""},
                        {"role": "user", "content": f"""
                        User Query: {query}
                        
                        Product Information:
                        {json.dumps(product_context, indent=2)}
                        
                        Is this product truly relevant to the user's query?
                        Consider:
                        1. Direct relevance to the query topic
                        2. Whether it actually addresses the user's need
                        3. How well it matches the specific request"""}
                    ],
                    response_format={ "type": "json_object" },
                    temperature=0.5
                )
                
                evaluation = json.loads(response.choices[0].message.content)
                
                if evaluation['is_relevant']:
                    # Adjust the vector score based on LLM relevance
                    result['score'] = result['score'] * evaluation['relevance_score']
                    filtered_results.append(result)
                    
                    logger.info(f"Filtered result: {metadata.get('productTitle')} - Score: {result['score']}")
                    logger.info(f"Reason: {evaluation['reason']}")
            
            # Sort by adjusted scores
            filtered_results.sort(key=lambda x: x['score'], reverse=True)
            return filtered_results
            
        except Exception as e:
            logger.error(f"Error in LLM filtering: {str(e)}")
            return vector_results  # Return original results if filtering fails

    async def _handle_report_query(self, query: str, requirements: Dict) -> str:
        """Handle queries about previous reports and product recommendations"""
        try:
            # Initial vector search
            vector_results = await VectorService.search_similar(
                query,
                limit=10,
                namespace="report-metadata"
            )
            
            logger.info(f"🔍 Search query: {query}")
            logger.info(f"📊 Retrieved {len(vector_results)} initial vector results")
            
            # Apply LLM filtering
            filtered_results = await self._filter_results_with_llm(query, vector_results)
            logger.info(f"🎯 Filtered down to {len(filtered_results)} relevant results")
            
            if not filtered_results:
                return "I couldn't find any relevant products that match your request."
            
            # Deduplicate products by URL to ensure unique items
            unique_products = {}  # Use URL as key to deduplicate
            for result in filtered_results:
                metadata = result.get('metadata', {})
                url = metadata.get('productUrl', '')
                
                # Only keep the highest scoring result for each product URL
                if url and (url not in unique_products or result['score'] > unique_products[url]['score']):
                    unique_products[url] = {
                        'title': metadata.get('productTitle', 'Unnamed Product'),
                        'url': url,
                        'summary': metadata.get('summary', ''),
                        'score': result['score']
                    }
            
            # Convert back to list and sort by score
            unique_results = sorted(
                unique_products.values(),
                key=lambda x: x['score'],
                reverse=True
            )
            
            # Format the response with unique products
            response_parts = ["I found these relevant products from our reports:\n\n"]
            
            for product in unique_results:
                display_title = product['title'][:100] + "..." if len(product['title']) > 100 else product['title']
                
                response_parts.append(f"• {display_title}")
                if product['url']:
                    short_url = self.shorten_url(product['url'])
                    response_parts.append(f"  Link: {short_url}")
                if product['summary']:
                    response_parts.append(f"  Summary: {product['summary']}")
                response_parts.append("")  # Add blank line between products
            
            # If multiple products found, use LLM to recommend the best option

            print(f"<THOR DEBUG> Found {len(unique_results)} unique results")

            if len(unique_results) > 1:
                # Fix: Format the products correctly to match what _get_specific_recommendation expects
                formatted_products = [{
                    'metadata': {
                        'productTitle': p['title'],
                        'url': p['url'],
                        'summary': p['summary']
                    },
                    'score': p['score']
                } for p in unique_results]
                
                recommendation = await self._get_specific_recommendation(
                    formatted_products,
                    requirements,
                    original_query=query
                )
                if recommendation:  # Only add if we got a recommendation
                    response_parts.append("\nBased on your needs, I recommend:")
                    response_parts.append(recommendation)
            
            return "\n".join(response_parts)
            
        except Exception as e:
            logger.error(f"Error handling report query: {str(e)}")
            return "I encountered an error while searching through the reports."

    async def _get_specific_recommendation(self, products: List[Dict], requirements: Dict, original_query: str) -> str:
        """Use LLM to analyze products and make a specific recommendation"""
        try:
            formatted_products = []
            for product in products:
                metadata = product.get('metadata', {})
                formatted_products.append({
                    'title': metadata.get('productTitle', ''),
                    'url': metadata.get('url', ''),
                    'summary': metadata.get('summary', ''),
                    'score': product.get('score', 0),
                })
            
            formatted_products = [p for p in formatted_products if p['title']]
            
            if not formatted_products:
                return ""  # Return empty string instead of error message
            
            products_context = json.dumps(formatted_products, indent=2)
            requirements_context = json.dumps(requirements, indent=2)
            
            response = self.openai_client.chat.completions.create(
                model="gpt-4-turbo-preview",
                messages=[
                    {"role": "system", "content": """You are a product recommendation expert.
                    You MUST recommend one of the provided products - no exceptions.
                    
                    Important Guidelines:
                    1. You MUST choose the product that best matches the user's query
                    2. Always include the EXACT product name and link
                    3. Explain why it's the best match for their specific needs
                    4. If no perfect match exists, choose the closest option
                    5. Never suggest unavailable products or say you can't recommend
                    
                    Format your response EXACTLY as:
                    I recommend the [Exact Product Name].
                    
                    Here's why this matches your needs:
                    [Your explanation focusing on how it matches their specific request]
                    """},
                    {"role": "user", "content": f"""
                    Original User Query: {original_query}
                    User Requirements: {requirements_context}
                    Available Products: {products_context}
                    
                    You MUST choose one product from the list that best matches their query.
                    Failure to recommend is not an option - pick the best match."""}
                ],
                temperature=0.3  # Lower temperature for more focused responses
            )
            print(response)
            print(f"<THOR DEBUG> Recommendation response: {response.choices[0].message.content}")
            
            recommendation = response.choices[0].message.content
            if "I recommend" not in recommendation:
                # Force a recommendation if the LLM didn't provide one
                return f"I recommend the {formatted_products[0]['title']}.\n\nThis product appears to be the best match for your needs."
            
            return recommendation
            
        except Exception as e:
            logger.error(f"Error getting specific recommendation: {str(e)}")
            return ""  # Return empty string on error

    def _is_video_request(self, content: str) -> bool:
        """Check if the user is asking for video recommendations"""
        video_keywords = [
            r"show.*video",
            r"find.*video",
            r"recommend.*video",
            r"similar video",
            r"related video",
            r"workout video",
            r"exercise video"
        ]
        
        content = content.lower()
        return any(re.search(pattern, content) for pattern in video_keywords)

    def _is_report_query(self, content: str) -> bool:
        """Check if the user is asking about reports or products"""
        report_keywords = [
            r"recommend.*product",
            r"which.*should I",
            r"what.*recommend",
            r"best.*product",
            r"report.*about",
            r"previous.*report"
        ]
        
        content = content.lower()
        return any(re.search(pattern, content) for pattern in report_keywords)

    def shorten_url(self, url: str) -> str:
        """Shorten a URL using TinyURL"""
        try:
            return self.url_shortener.tinyurl.short(url)
        except Exception as e:
            logger.error(f"Error shortening URL: {str(e)}")
            return url  # Return original URL if shortening fails 

    def get_current_trace_id(self) -> str:
        """Get the current trace ID from the LangSmith context"""
        ctx = get_run_tree_context()
        return ctx.id if ctx else None 