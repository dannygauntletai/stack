from typing import Dict, Any, List
import aiohttp
import json
from openai import OpenAI
from firebase_admin import firestore
from services.db_service import DatabaseService
from services.agents.base_agent import BaseAgent
from services.vector_service import VectorService
from config import Config
import logging
import uuid
import datetime
import time
import asyncio
import os
from langsmith import traceable
from langsmith.wrappers import wrap_openai

logger = logging.getLogger(__name__)

class ResearchAgent(BaseAgent):
    def __init__(self, db_service: DatabaseService):
        self.db_service = db_service
        # Wrap OpenAI client for tracing
        self.openai_client = wrap_openai(OpenAI(api_key=Config.OPENAI_API_KEY))
        self.tavily_api_key = Config.TAVILY_API_KEY
        
        # Set project and run names for research agent
        self.project_name = "thorgodoflightning"
        self.run_name = "research"
        
        # Explicitly set LangSmith environment variables
        os.environ["LANGCHAIN_TRACING_V2"] = "true"
        os.environ["LANGCHAIN_PROJECT"] = self.project_name
        
        # Log LangSmith configuration
        logger.info(f"Research Agent LangSmith Configuration:")
        logger.info(f"Project Name: {self.project_name}")
        logger.info(f"Run Name: {self.run_name}")
        logger.info(f"LANGCHAIN_API_KEY set: {bool(os.getenv('LANGCHAIN_API_KEY'))}")
        logger.info(f"LANGCHAIN_TRACING_V2: {os.getenv('LANGCHAIN_TRACING_V2')}")

    def validate_input(self, input_data: Dict[str, Any]) -> bool:
        """Validate the product data"""
        required_fields = ['id', 'title', 'productUrl']
        return all(field in input_data for field in required_fields)

    @traceable(project_name="thorgodoflightning", name="research")
    async def process(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        """Process product research"""
        if not self.validate_input(input_data):
            raise ValueError("Invalid product data")

        # Perform Tavily search with full product data
        search_results = await self._tavily_search(input_data)
        
        # Generate summary
        research_summary = await self._generate_summary(input_data, search_results)
        
        # Create report document with Unix timestamp
        report = {
            'id': str(uuid.uuid4()),
            'productId': input_data['id'],
            'productTitle': input_data['title'],
            'productUrl': input_data['productUrl'],
            'research': research_summary,
            'searchResults': search_results,
            'timestamp': time.time()  # Unix timestamp as double
        }
        
        # Save to Firebase (with Firestore timestamp)
        firebase_report = report.copy()
        firebase_report['timestamp'] = firestore.SERVER_TIMESTAMP
        report_ref = self.db_service.db.collection('reports').document()
        report_ref.set(firebase_report)

        # Create text representation for vectorization
        report_text = f"""
        Product: {report['productTitle']}
        Summary: {report['research']['summary']}
        Key Points: {' '.join(report['research']['keyPoints'])}
        Pros: {' '.join(report['research']['pros'])}
        Cons: {' '.join(report['research']['cons'])}
        """

        try:
            # Debug logging
            logger.info("Vectorizing report:")
            logger.info(f"Report ID: {report['id']}")
            logger.info(f"Report Text: {report_text}")
            
            metadata = {
                'id': report['id'],
                'productId': report['productId'],
                'productTitle': report['productTitle'],
                'productUrl': report['productUrl'],
                'summary': report['research']['summary'],
                'timestamp': report['timestamp']
            }
            logger.info(f"Metadata: {json.dumps(metadata)}")

            # Get embedding from OpenAI
            embedding_response = self.openai_client.embeddings.create(
                model="text-embedding-3-small",
                input=report_text
            )
            
            vector_data = {
                'id': report['id'], 
                'vector': embedding_response.data[0].embedding,
                'metadata': metadata
            }
            
            logger.info(f"Vector dimensions: {len(vector_data['vector'])}")
            
            # Store in Pinecone with reports-metadata namespace
            await VectorService.upsert_vectors(
                vectors=[(
                    vector_data['id'],
                    vector_data['vector'],
                    vector_data['metadata']
                )],
                namespace="report-metadata"
            )
            logger.info("Successfully vectorized and stored report")
            
        except Exception as e:
            logger.error(f"Error vectorizing report: {str(e)}", exc_info=True)
        
        return report  # Return the Unix timestamp version 

    @traceable(project_name="thorgodoflightning", name="research_search")
    async def _tavily_search(self, product: Dict) -> List[Dict]:
        """Perform Tavily search with comprehensive product info"""
        search_terms = []
        
        if product.get('title'):
            search_terms.append(f"\"{product['title']}\"")  # Exact match
            
        if product.get('asin'):
            search_terms.append(f"site:amazon.com {product['asin']}")
            
        # Add review terms
        search_terms.append("product review specifications features")
        
        # Join all terms
        search_query = " ".join(search_terms)
        logger.debug(f"Search query: {search_query}")
        
        # Create timeout for client session
        timeout = aiohttp.ClientTimeout(total=30)  # 30 second timeout
        
        async with aiohttp.ClientSession(timeout=timeout) as session:
            url = "https://api.tavily.com/search"
            
            headers = {
                "content-type": "application/json",
                "Authorization": f"Bearer {self.tavily_api_key}"
            }
            
            payload = {
                "query": search_query,
                "search_depth": "basic",  # Changed from advanced to basic
                "include_answer": True,
                "max_results": 5,
                "include_domains": ["amazon.com"],
                "exclude_domains": ["pinterest.com", "facebook.com", "instagram.com"]
            }
            
            max_retries = 3
            retry_delay = 1  # seconds
            
            for attempt in range(max_retries):
                try:
                    async with session.post(url, json=payload, headers=headers) as response:
                        if response.status == 502:
                            error_text = await response.text()
                            logger.error(f"Tavily 502 error (attempt {attempt + 1}/{max_retries}): {error_text}")
                            logger.error(f"Request details: URL={url}, Query={search_query}")
                            if attempt < max_retries - 1:
                                await asyncio.sleep(retry_delay * (attempt + 1))
                                continue
                            return []
                            
                        if response.status != 200:
                            error_text = await response.text()
                            logger.error(f"Tavily error {response.status}: {error_text}")
                            return []
                            
                        result = await response.json()
                        return result.get('results', [])
                        
                except asyncio.TimeoutError:
                    logger.error(f"Tavily request timed out after {timeout.total} seconds (attempt {attempt + 1}/{max_retries})")
                    if attempt < max_retries - 1:
                        await asyncio.sleep(retry_delay * (attempt + 1))
                        continue
                    return []
                        
                except Exception as e:
                    logger.error(f"Tavily request failed (attempt {attempt + 1}/{max_retries}): {str(e)}")
                    if attempt < max_retries - 1:
                        await asyncio.sleep(retry_delay * (attempt + 1))
                        continue
                    return []
            
            return []  # If all retries failed

    @traceable(project_name="thorgodoflightning", name="research_summary")
    async def _generate_summary(self, product: Dict, search_results: List[Dict]) -> Dict:
        """Generate a summary using OpenAI"""
        prompt = f"""Analyze this product and search results to create a detailed research summary.
        
        Product: {product['title']}
        
        Search Results:
        {json.dumps(search_results, indent=2)}
        
        Create a research summary that STRICTLY follows this JSON format with NO additional fields:
        {{
            "summary": "A concise overview of the product findings (1-2 sentences)",
            "keyPoints": ["Important point 1", "Important point 2", "Important point 3"],
            "pros": ["Clear benefit 1", "Clear benefit 2"],
            "cons": ["Drawback 1", "Drawback 2"],
            "sources": ["Source URL 1", "Source URL 2"]
        }}
        
        Requirements:
        1. Use EXACTLY the field names shown above
        2. Ensure valid JSON format
        3. Include at least 2 items in each array
        4. Keep summary concise
        5. Use factual information from search results
        6. Include source URLs from the search results
        """

        response = self.openai_client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "You are a product research specialist. Always return valid JSON."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.7,
            response_format={ "type": "json_object" }  # Force JSON response
        )
        
        try:
            return json.loads(response.choices[0].message.content)
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse OpenAI response: {e}")
            # Return a fallback response
            return {
                "summary": "Unable to generate research summary.",
                "keyPoints": ["No data available", "Please try again"],
                "pros": ["Not available"],
                "cons": ["Not available"],
                "sources": []
            } 