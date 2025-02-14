import sys
import os

# Add the parent directory to Python path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi.testclient import TestClient
from services.firebase_service import FirebaseService
from services.db_service import DatabaseService
from services.vector_service import VectorService
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def test_vector_search():
    """Test various vector search queries"""
    
    try:
        # Initialize services
        FirebaseService.initialize()
        db_service = DatabaseService(FirebaseService.get_db())
        
        # Test queries
        test_queries = [
            # Exercise/Sport Related
            "soccer workout tips",
            "high intensity sports training",
            "muscle recovery exercises",
            
            # Supplement Related
            "pre workout supplements for sports",
            "post workout recovery supplements",
            "supplements for muscle recovery",
            
            # Health Impact Related
            "improve cardiovascular health through sports",
            "exercises for muscle strength and endurance",
            "prevent sports injuries",
            
            # Generic Related
            "sports nutrition advice",
            "athletic performance tips",
            "workout recovery guidance"
        ]
        
        for query in test_queries:
            try:
                # Search directly using VectorService
                results = await VectorService.search_similar(query, limit=3)
                
                # Log results
                logger.info(f"\nQuery: {query}")
                logger.info(f"Found {len(results)} results")
                
                # Print details of matches
                for result in results:
                    logger.info(f"\nVideo ID: {result['id']}")
                    logger.info(f"Similarity Score: {result['score']:.3f}")
                    
                    # Print metadata if available
                    metadata = result.get('metadata', {})
                    logger.info(f"Title: {metadata.get('title', 'N/A')}")
                    logger.info(f"Content Type: {metadata.get('content_type', 'N/A')}")
                    logger.info(f"Tags: {metadata.get('tags', [])}")
                    logger.info(f"Supplements: {metadata.get('supplement_recommendations', [])}")
                    
            except Exception as e:
                logger.error(f"Error testing query '{query}': {str(e)}")
                
    except Exception as e:
        logger.error(f"Setup error: {str(e)}")

if __name__ == "__main__":
    import asyncio
    
    # Run the async test
    logger.info("Starting vector search tests...")
    asyncio.run(test_vector_search())
    logger.info("Vector search tests completed") 