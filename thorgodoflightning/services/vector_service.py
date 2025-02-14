from typing import Dict, List
from pinecone import Pinecone, ServerlessSpec
from config import Config
import logging
from datetime import datetime
from openai import OpenAI
import json
import asyncio

logger = logging.getLogger(__name__)

class VectorService:
    _instance = None
    _openai_client = None
    _pinecone_client = None

    @classmethod
    def initialize(cls):
        """Initialize Pinecone connection"""
        if not cls._instance:
            try:
                # Initialize Pinecone client
                cls._pinecone_client = Pinecone(
                    api_key=Config.PINECONE_API_KEY
                )

                # Create index if it doesn't exist
                if Config.PINECONE_INDEX_NAME not in cls._pinecone_client.list_indexes().names():
                    cls._pinecone_client.create_index(
                        name=Config.PINECONE_INDEX_NAME,
                        dimension=1536,  # OpenAI embedding dimension
                        metric="cosine",
                        spec=ServerlessSpec(
                            cloud="aws",
                            region=Config.PINECONE_ENVIRONMENT
                        )
                    )

                # Get index instance
                cls._instance = cls._pinecone_client.Index(Config.PINECONE_INDEX_NAME)
                
                # Initialize OpenAI client
                cls._openai_client = OpenAI(api_key=Config.OPENAI_API_KEY)
                
                logger.info(f"Pinecone initialized successfully with index: {Config.PINECONE_INDEX_NAME}")
            except Exception as e:
                logger.error(f"Failed to initialize Pinecone: {str(e)}", exc_info=True)
                raise

    @classmethod
    async def _generate_embeddings(cls, data: Dict) -> List[float]:
        """Generate embeddings using OpenAI's API"""
        if not cls._openai_client:
            cls.initialize()

        # Create a rich text representation of the video data
        text_content = []
        
        # Add video title and description if available
        if 'title' in data:
            text_content.append(f"Title: {data['title']}")
        if 'description' in data:
            text_content.append(f"Description: {data['description']}")
            
        # Add content categories and activities
        if 'content_categories' in data:
            cats = data['content_categories']
            if 'primary_category' in cats:
                text_content.append(f"Category: {cats['primary_category']}")
            if 'activities' in cats:
                activities = [f"{a['label']} ({a['confidence']:.2f})" 
                            for a in cats['activities']]
                text_content.append(f"Activities: {', '.join(activities)}")
            if 'environment' in cats:
                text_content.append(f"Environment: {cats['environment']}")

        # Add health analysis if available
        if 'healthAnalysis' in data:
            health = data['healthAnalysis']
            if 'summary' in health:
                text_content.append(f"Health Impact: {health['summary']}")
            if 'benefits' in health:
                text_content.append(f"Benefits: {', '.join(health['benefits'])}")
            if 'tags' in health:
                text_content.append(f"Tags: {', '.join(health['tags'])}")

        # Join all content with newlines
        full_text = "\n".join(text_content)

        try:
            response = cls._openai_client.embeddings.create(
                model="text-embedding-ada-002",
                input=full_text
            )
            return response.data[0].embedding
        except Exception as e:
            logger.error(f"Failed to generate embeddings: {str(e)}")
            raise

    @classmethod
    async def vectorize_video(cls, video_data: Dict) -> Dict:
        """Generate vector embeddings for video metadata"""
        if not cls._instance:
            cls.initialize()
            
        try:
            # Generate embeddings from video metadata
            vector = await cls._generate_embeddings(video_data)
            
            # Get health analysis data
            health_analysis = video_data.get('healthAnalysis', {})
            
            # Extract supplement names for metadata
            supplement_names = [
                supp.get('name', '') 
                for supp in health_analysis.get('supplement_recommendations', [])[:2]  # Limit to 2 supplements
            ]
            
            # Store in Pinecone with sanitized metadata
            metadata = {
                'video_id': str(video_data['id']),
                'title': str(video_data.get('caption', '')),
                'content_type': str(health_analysis.get('content_type', '')),
                'summary': str(health_analysis.get('summary', '')),
                'health_score': float(video_data.get('healthImpactScore', 0)),
                'benefits': health_analysis.get('benefits', []),
                'tags': health_analysis.get('tags', [])[:3],
                'longevity_impact': str(health_analysis.get('longevity_impact', '')),
                'supplement_recommendations': supplement_names,  # List of supplement names
                'indexed_at': datetime.now().isoformat()
            }
            
            # Filter out any None or empty values
            metadata = {k: v for k, v in metadata.items() if v not in [None, '', [], {}]}
            
            cls._instance.upsert(
                vectors=[(video_data['id'], vector, metadata)],
                namespace="video-metadata"
            )
            
            return {
                'id': video_data['id'],
                'metadata': metadata
            }
        except Exception as e:
            logger.error(f"Error vectorizing video: {str(e)}", exc_info=True)
            raise

    @classmethod
    async def search_similar(cls, query: str, limit: int = 10) -> List[Dict]:
        """Search for similar videos using vector similarity"""
        if not cls._instance:
            cls.initialize()
            
        try:
            # Generate query vector
            query_vector = await cls._generate_embeddings({'text': query})
            
            # Search Pinecone
            results = cls._instance.query(
                vector=query_vector,
                top_k=limit,
                namespace="video-metadata",
                include_metadata=True
            )
            
            return [{
                'id': match.id,
                'score': match.score,
                'metadata': match.metadata
            } for match in results.matches]
        except Exception as e:
            logger.error(f"Error searching vectors: {str(e)}", exc_info=True)
            raise

    @classmethod
    async def search_k_similar(cls, query: str, limit: int = 3) -> List[Dict]:
        """Search for similar videos using multiple LLM-generated queries"""
        if not cls._instance:
            cls.initialize()
            
        try:
            # Generate multiple search queries using LLM
            client = OpenAI(api_key=Config.OPENAI_API_KEY)
            response = client.chat.completions.create(
                model="gpt-4-turbo-preview",
                messages=[
                    {"role": "system", "content": "Generate 5 different search queries that capture different aspects of the user's video request. Make each query specific and focused on different aspects. Return only the queries, one per line."},
                    {"role": "user", "content": query}
                ],
                temperature=0.7
            )
            
            # Split queries into list
            search_queries = response.choices[0].message.content.strip().split('\n')
            print(f"🔍 Generated queries: {search_queries}")
            
            # Search with each query
            search_tasks = [cls.search_similar(q, limit=limit) for q in search_queries]
            all_results = await asyncio.gather(*search_tasks)
            
            # Combine and deduplicate results
            seen_ids = set()
            unique_results = []
            
            # Flatten and deduplicate while keeping highest scores
            for results in all_results:
                for result in results:
                    video_id = result['id']
                    if video_id not in seen_ids:
                        seen_ids.add(video_id)
                        unique_results.append(result)
                    else:
                        # If we've seen this ID, update if new score is higher
                        existing_idx = next(i for i, r in enumerate(unique_results) if r['id'] == video_id)
                        if result['score'] > unique_results[existing_idx]['score']:
                            unique_results[existing_idx] = result
            
            # Sort by score and limit results
            final_results = sorted(unique_results, key=lambda x: x['score'], reverse=True)[:limit]
            print(f"✨ Found {len(final_results)} unique videos")
            
            return final_results
            
        except Exception as e:
            logger.error(f"Error in search_k_similar: {str(e)}", exc_info=True)
            raise