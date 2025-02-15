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

logger = logging.getLogger(__name__)

class ChatAgent(BaseAgent):
    def __init__(self, db_service: DatabaseService):
        self.db_service = db_service
        self.openai_client = OpenAI(api_key=Config.OPENAI_API_KEY)
        self.url_shortener = pyshorteners.Shortener()
        
        # Explicitly set LangSmith environment variables
        os.environ["LANGCHAIN_TRACING_V2"] = "true"
        os.environ["LANGCHAIN_PROJECT"] = Config.LANGSMITH_PROJECT
        
        # Log LangSmith configuration
        logger.info(f"LangSmith Configuration:")
        logger.info(f"LANGCHAIN_API_KEY set: {bool(os.getenv('LANGCHAIN_API_KEY'))}")
        logger.info(f"LANGCHAIN_TRACING_V2: {os.getenv('LANGCHAIN_TRACING_V2')}")
        logger.info(f"LANGSMITH_PROJECT: {os.getenv('LANGSMITH_PROJECT')}")
        logger.info(f"LANGSMITH_ENDPOINT: {os.getenv('LANGSMITH_ENDPOINT')}")
        
    def validate_input(self, input_data: Dict[str, Any]) -> bool:
        """Validate the input data"""
        required_fields = ['content', 'type', 'session_id']
        return all(field in input_data for field in required_fields)
        
    @traceable(project_name="thorgodoflightning")
    async def process(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        """Process a chat message"""
        try:
            if not self.validate_input(input_data):
                raise ValueError("Invalid chat input")
            
            message_text = input_data['content']
            conversation_id = input_data.get('session_id')
            user_id = input_data.get('userId')
            
            # Start vector search with its own trace
            video_ids = await self._search_videos(message_text)
            
            # Generate response with context and session data
            response = await self._generate_response(message_text, video_ids, input_data)
            
            return response
                
        except Exception as e:
            logger.error(f"Error in process with tracing: {str(e)}", exc_info=True)
            raise

    @traceable(project_name="thorgodoflightning")
    async def _search_videos(self, query: str) -> List[str]:
        """Search for relevant videos"""
        try:
            # Use enhanced search with parsed query and video namespace
            vector_results = await VectorService.search_k_similar(
                query,
                limit=1,
                namespace="video-metadata"  # Specify the video namespace
            )
            video_ids = [result['id'] for result in vector_results]
            return video_ids
        except Exception as e:
            logger.error(f"Error in search with tracing: {str(e)}", exc_info=True)
            raise

    @traceable(project_name="thorgodoflightning")
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
            
            # Store response
            assistant_message = {
                'content': response_text,
                'type': 'text',
                'session_id': session_data['session_id'],
                'role': 'assistant',
                'sequence': session_data.get('sequence_number', 0),
                'timestamp': time.time(),
                'senderId': 'AI'
            }
            
            # Save to database and get document reference
            message_ref = self.db_service.db.collection('messages').document()
            message_ref.set(assistant_message)
            
            # Get trace ID once
            trace_id = self.get_current_trace_id()
            
            # Return complete response structure with trace ID in two places
            return {
                'success': True,
                'trace_id': trace_id,  # Add at top level
                'message': {
                    'id': message_ref.id,
                    'text': response_text,
                    'videoIds': video_ids,
                    'isFromCurrentUser': False,
                    'timestamp': time.time(),
                    'senderId': 'ai',
                    'feedback': {
                        'status': 'pending',
                        'trace_id': trace_id  # Keep in feedback object too
                    }
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
        vector_results = await VectorService.search_k_similar(
            query,
            limit=1,
            namespace="video-metadata"  # Specify the video namespace
        )
        video_ids = [result['id'] for result in vector_results]
        videos = await self.db_service.get_videos_by_ids(video_ids)
        
        # Format video response
        response_text = "Here are some relevant videos:\n"
        for video in videos:
            response_text += f"{video.get('caption', 'Untitled')}\n"
            response_text += f"  Video ID: {video['id']}\n\n"
            
        return response_text
        
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

    async def _handle_report_query(self, query: str, requirements: Dict) -> str:
        """Handle queries about previous reports and product recommendations"""
        try:
            # Use search_k_similar with the report-metadata namespace and increased limit
            vector_results = await VectorService.search_k_similar(
                query,
                limit=10,  # Increased from 3 to 10 to get more potential matches
                namespace="report-metadata"
            )
            
            logger.info(f"🔍 Search query: {query}")
            logger.info(f"📊 Retrieved {len(vector_results)} vector results from report-metadata namespace")
            
            # Log each result's full content
            for i, result in enumerate(vector_results):
                logger.info(f"\n=== Result {i+1} ===")
                logger.info(f"Score: {result.get('score')}")
                logger.info(f"ID: {result.get('id')}")
                logger.info("Metadata:")
                for key, value in result.get('metadata', {}).items():
                    logger.info(f"  {key}: {value}")
                logger.info("=" * 50)
            
            if not vector_results:
                return "I couldn't find any relevant reports about that topic."
            
            # Deduplicate products by URL to ensure unique items
            unique_products = {}  # Use URL as key to deduplicate
            for result in vector_results:
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
            if len(unique_results) > 1:
                recommendation = await self._get_specific_recommendation(
                    [{'metadata': p, 'score': p['score']} for p in unique_results],
                    requirements,
                    original_query=query  # Pass the original query
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
                    
                    You can find it here: [Product Link]"""},
                    {"role": "user", "content": f"""
                    Original User Query: {original_query}
                    User Requirements: {requirements_context}
                    Available Products: {products_context}
                    
                    You MUST choose one product from the list that best matches their query.
                    Failure to recommend is not an option - pick the best match."""}
                ],
                temperature=0.3  # Lower temperature for more focused responses
            )
            
            recommendation = response.choices[0].message.content
            if "I recommend" not in recommendation:
                # Force a recommendation if the LLM didn't provide one
                return f"I recommend the {formatted_products[0]['title']}.\n\nThis product appears to be the best match for your needs.\n\nYou can find it here: {formatted_products[0]['url']}"
            
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