from typing import Dict, List
import pinecone
from config import Config
import logging
from datetime import datetime

logger = logging.getLogger(__name__)

class VectorService:
    _instance = None

    @classmethod
    def initialize(cls):
        """Initialize Pinecone connection"""
        if not cls._instance:
            try:
                pinecone.init(
                    api_key=Config.PINECONE_API_KEY,
                    environment=Config.PINECONE_ENVIRONMENT,
                    project_id=Config.PINECONE_PROJECT_ID
                )
                cls._instance = pinecone.Index(Config.PINECONE_INDEX_NAME)
                logger.info(f"Pinecone initialized successfully with index: {Config.PINECONE_INDEX_NAME}")
            except Exception as e:
                logger.error(f"Failed to initialize Pinecone: {str(e)}", exc_info=True)
                raise

    @classmethod
    async def vectorize_video(cls, video_data: Dict) -> Dict:
        """Generate vector embeddings for video metadata"""
        if not cls._instance:
            cls.initialize()
            
        try:
            # Generate embeddings from video metadata
            # This could include:
            # - Caption text
            # - Health analysis results
            # - Video labels/categories
            # - User metadata
            vector = await cls._generate_embeddings(video_data)
            
            # Store in Pinecone
            cls._instance.upsert(
                vectors=[(video_data['id'], vector, video_data)],
                namespace="video-metadata"
            )
            
            return {
                'id': video_data['id'],
                'metadata': {
                    'vector_dim': len(vector),
                    'indexed_at': datetime.now().isoformat()
                }
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
                namespace="video-metadata"
            )
            
            return results.matches
        except Exception as e:
            logger.error(f"Error searching vectors: {str(e)}", exc_info=True)
            raise