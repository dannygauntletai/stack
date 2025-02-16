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
    async def _generate_embeddings(cls, text: str) -> List[float]:
        """Generate embeddings using OpenAI's API"""
        if not cls._openai_client:
            cls.initialize()

        try:
            response = cls._openai_client.embeddings.create(
                model="text-embedding-ada-002",
                input=text
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
            # Extract and vectorize only the summary
            health_analysis = video_data.get('healthAnalysis', {})
            # Get the actual text content from the summary
            summary_text = health_analysis.get('summary', '')
            if isinstance(summary_text, dict):
                summary_text = summary_text.get('summary', '')
            
            print(f"<THOR DEBUG> Vectorizing summary: {summary_text[:200]}...")  # Print first 200 chars
            
            if not summary_text:
                logger.warning(f"No summary found for video {video_data.get('id')}")
                summary_text = "No summary available"
                
            # Generate embeddings from summary textf
            vector = await cls._generate_embeddings(summary_text)
            
            # Store in Pinecone with sanitized metadata
            metadata = {
                'video_id': str(video_data['id']),
                'summary': summary_text,  # Store actual text for retrieval
                'tags': health_analysis.get('tags', [])[:3],
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
    async def search_similar(cls, query: str, limit: int = 10, namespace: str = "video-metadata") -> List[Dict]:
        """Search for similar items using vector similarity"""
        if not cls._instance:
            cls.initialize()

        try:
            # Generate query vector
            query_vector = await cls._generate_embeddings(query)
            
            # Search Pinecone with namespace
            results = cls._instance.query(
                vector=query_vector,
                top_k=limit,
                namespace=namespace,
                include_metadata=True
            )
            print("================================================")
            print(f"<THOR DEBUG> Found {len(results.matches)} matches")
            print(results.matches)
            print("================================================")
            
            return [{
                'id': match.id,
                'score': match.score,
                'metadata': match.metadata
            } for match in results.matches]
        except Exception as e:
            logger.error(f"Error searching vectors: {str(e)}", exc_info=True)
            raise

    @classmethod
    async def upsert_vectors(cls, vectors: List[tuple], namespace: str):
        """Upsert vectors to Pinecone index with specified namespace"""
        if not cls._instance:
            cls.initialize()
            
        try:
            # Vectors should be in format: [(id, vector, metadata)]
            cls._instance.upsert(
                vectors=vectors,
                namespace=namespace
            )
            logger.info(f"Successfully upserted {len(vectors)} vectors to namespace: {namespace}")
            
        except Exception as e:
            logger.error(f"Error upserting vectors: {str(e)}", exc_info=True)
            raise