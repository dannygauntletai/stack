from fastapi import APIRouter, HTTPException, Depends
from typing import Annotated
from dependencies import get_db_service
from services.db_service import DatabaseService
from services.firebase_service import FirebaseService
from services.vector_service import VectorService
import logging
import os

router = APIRouter(
    prefix="/health",
    tags=["health"]
)

logger = logging.getLogger(__name__)

# Define reusable dependency
DBServiceDep = Annotated[DatabaseService, Depends(get_db_service)]

@router.get("")
async def health_check(db_service: DBServiceDep):
    """
    Health check endpoint that verifies:
    1. API is running
    2. Database connection is working
    3. Firebase Admin SDK is initialized
    4. Vector service is available
    5. Required environment variables are set
    """
    try:
        health_status = {
            'status': 'healthy',
            'service': 'video_health_analysis',
            'version': '1.0.0',
            'components': {}
        }

        # Check database connection
        try:
            await db_service.check_connection()
            health_status['components']['database'] = 'connected'
        except Exception as e:
            health_status['components']['database'] = f'error: {str(e)}'
            health_status['status'] = 'degraded'

        # Check Firebase
        try:
            firebase_app = FirebaseService.get_app()
            health_status['components']['firebase'] = 'initialized'
        except Exception as e:
            health_status['components']['firebase'] = f'error: {str(e)}'
            health_status['status'] = 'degraded'

        # Check Vector Service
        try:
            VectorService.initialize()
            health_status['components']['vector_service'] = 'initialized'
        except Exception as e:
            health_status['components']['vector_service'] = f'error: {str(e)}'
            health_status['status'] = 'degraded'

        # Check environment variables
        required_categories = {
            'OpenAI': ['OPENAI_API_KEY'],
            'Google Cloud': ['PROJECT_ID', 'GOOGLE_APPLICATION_CREDENTIALS'],
            'Firebase': ['FIREBASE_STORAGE_BUCKET'],
            'Pinecone': ['PINECONE_API_KEY', 'PINECONE_INDEX_NAME']
        }
        
        missing = {}
        for category, vars in required_categories.items():
            missing_vars = [var for var in vars if not os.getenv(var)]
            if missing_vars:
                missing[category] = missing_vars
                health_status['status'] = 'degraded'
        
        if missing:
            health_status['components']['configuration'] = {
                'status': 'incomplete',
                'missing': missing
            }
        else:
            health_status['components']['configuration'] = {
                'status': 'complete'
            }

        return health_status

    except Exception as e:
        logger.error(f"Health check failed: {str(e)}", exc_info=True)
        return {
            'status': 'unhealthy',
            'error': str(e),
            'service': 'video_health_analysis'
        } 