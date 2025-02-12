from typing import Dict, List
import logging
from config import Config
import aiohttp
import json
from datetime import datetime
import openai
from services.firebase_service import FirebaseService
import uuid
from firebase_admin import firestore

logger = logging.getLogger(__name__)

class ResearchService:
    @staticmethod
    async def research_products(research_id: str, products: List[Dict]):
        """Research and compare products using Tavily and OpenAI"""
        doc_ref = None
        try:
            db = FirebaseService.get_db()
            
            # Store in a dedicated collection for product research
            doc_ref = db.collection('product_research').document(research_id)
            
            # Initial document creation
            doc_ref.set({
                'id': research_id,
                'status': 'in_progress',
                'products': products,
                'started_at': firestore.SERVER_TIMESTAMP,
                'updated_at': firestore.SERVER_TIMESTAMP
            })
            
            # Research each product
            research_data = []
            for product in products:
                search_query = f"{product['title']} {product['asin']} amazon review"
                tavily_results = await ResearchService._tavily_search(product, search_query)
                
                research_data.append({
                    'product_id': product['id'],
                    'title': product['title'],
                    'asin': product['asin'],
                    'price': product['price'],
                    'sources': tavily_results,
                    'timestamp': datetime.utcnow().isoformat()
                })
            
            # Generate comparison using OpenAI
            comparisons = await ResearchService._generate_comparisons(research_data)
            
            # Update with results
            doc_ref.update({
                'status': 'completed',
                'results': {
                    'comparisons': comparisons,
                    'sources': [
                        {
                            'id': str(uuid.uuid4()),
                            'title': source['title'],
                            'url': source['url'],
                            'relevance_score': source.get('relevance_score', 0.0)
                        }
                        for result in research_data 
                        for source in result['sources']
                    ],
                    'timestamp': firestore.SERVER_TIMESTAMP
                },
                'updated_at': firestore.SERVER_TIMESTAMP
            })
            
        except Exception as e:
            logger.error(f"Research failed: {str(e)}", exc_info=True)
            if doc_ref:
                doc_ref.update({
                    'status': 'error',
                    'error': str(e),
                    'updated_at': firestore.SERVER_TIMESTAMP
                })
            raise

    @staticmethod
    async def _tavily_search(product: Dict, query: str) -> List[Dict]:
        """Perform Tavily search for product information"""
        try:
            async with aiohttp.ClientSession() as session:
                headers = {
                    'Content-Type': 'application/json',
                    'X-API-Key': Config.TAVILY_API_KEY
                }
                
                async with session.get(
                    'https://api.tavily.com/search',
                    params={
                        'query': query,
                        'search_depth': 'advanced',
                        'include_domains': ['amazon.com', 'reddit.com', 'trustpilot.com'],
                        'max_results': 5
                    },
                    headers=headers
                ) as response:
                    data = await response.json()
                    return data['results']
                    
        except Exception as e:
            logger.error(f"Tavily search failed: {str(e)}", exc_info=True)
            raise

    @staticmethod
    async def _generate_comparisons(research_data: List[Dict]) -> List[Dict]:
        """Generate product comparisons using OpenAI"""
        try:
            client = openai.OpenAI(api_key=Config.OPENAI_API_KEY)
            
            prompt = """Analyze the following product research data and generate detailed comparisons.
            Focus on:
            1. Key features and specifications
            2. Price-value analysis
            3. User reviews and satisfaction
            4. Pros and cons
            5. Best use cases
            
            Format the response as a JSON array of comparison objects with these fields:
            - id: unique string
            - category: comparison category
            - analysis: detailed analysis text
            """
            
            response = client.chat.completions.create(
                model="gpt-4",
                messages=[
                    {"role": "system", "content": prompt},
                    {"role": "user", "content": json.dumps(research_data)}
                ],
                temperature=0.7
            )
            
            return json.loads(response.choices[0].message.content)
            
        except Exception as e:
            logger.error(f"OpenAI comparison failed: {str(e)}", exc_info=True)
            raise

    @staticmethod
    async def get_research_status(research_id: str) -> Dict:
        """Get the current status of a research task"""
        try:
            db = FirebaseService.get_db()
            doc = db.collection('product_research').document(research_id).get()
            
            if not doc.exists:
                raise ValueError("Research not found")
                
            data = doc.to_dict()
            return {
                'status': data['status'],
                'results': data.get('results'),
                'error': data.get('error'),
                'updated_at': data['updated_at'].isoformat() if data.get('updated_at') else None
            }
            
        except Exception as e:
            logger.error(f"Failed to get research status: {str(e)}", exc_info=True)
            raise 