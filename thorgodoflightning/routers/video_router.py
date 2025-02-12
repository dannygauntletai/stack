from fastapi import APIRouter, HTTPException, Request, Path, Depends
from typing import Dict, Optional, Annotated
from services.video_service import VideoService
from services.health_service import HealthService
from services.vector_service import VectorService
from services.db_service import DatabaseService
from services.recommendation_service import RecommendationService
from dependencies import get_db_service, get_recommendation_service
from firebase_admin import auth
import logging
import traceback
import uuid

router = APIRouter(
    prefix="/videos",
    tags=["videos"]
)

logger = logging.getLogger(__name__)

# Define reusable dependency
DBServiceDep = Annotated[DatabaseService, Depends(get_db_service)]

# Add to dependencies
RecommendationDep = Annotated[RecommendationService, Depends(get_recommendation_service)]

@router.get("/{video_id}")
async def get_video(
    request: Request,
    db_service: DBServiceDep,
    video_id: str = Path(..., description="The ID of the video to retrieve")
) -> Dict:
    """Get video details"""
    try:
        # Auth verification
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            raise HTTPException(status_code=401, detail="No valid authorization header")
            
        token = auth_header.split(' ')[1]
        try:
            decoded_token = auth.verify_id_token(token)
        except Exception as e:
            raise HTTPException(status_code=401, detail="Invalid token")

        video_data = await db_service.get_video_by_id(video_id)
        if not video_data:
            raise HTTPException(status_code=404, detail="Video not found")
            
        return {
            'success': True,
            'video': video_data
        }
    except Exception as e:
        print(f"<THOR_DEBUG> Router error: {str(e)}")
        print("<THOR_DEBUG> Error traceback: ", traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/analyze")
async def analyze_video(request: Request, db_service: DBServiceDep) -> Dict:
    """Analyze video content and health impact"""
    request_id = str(uuid.uuid4())[:8]  # Add for request tracking
    logger.info(f"[{request_id}] Starting video analysis")
    try:
        # Log request headers for debugging
        headers = dict(request.headers)
        logger.debug(f"[{request_id}] Request headers: {headers}")
        
        # Get request body
        try:
            body = await request.json()
            logger.debug(f"[{request_id}] Request body: {body}")
        except Exception as e:
            logger.error(f"[{request_id}] Failed to parse request body: {str(e)}", exc_info=True)
            raise HTTPException(status_code=400, detail="Invalid request body")

        # Verify authentication
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            logger.error(f"[{request_id}] No valid authorization header")
            raise HTTPException(status_code=401, detail="No valid authorization header")
            
        token = auth_header.split(' ')[1]
        try:
            decoded_token = auth.verify_id_token(token)
            logger.info(f"[{request_id}] Authentication successful for user: {decoded_token['uid']}")
        except Exception as e:
            logger.error(f"[{request_id}] Token verification failed: {str(e)}", exc_info=True)
            raise HTTPException(status_code=401, detail="Invalid token")

        # Get request data
        video_url = body.get("videoUrl")
        if not video_url:
            logger.error(f"[{request_id}] Missing videoUrl in request")
            raise HTTPException(status_code=400, detail="Missing videoUrl in request")

        logger.info(f"[{request_id}] Processing video URL: {video_url}")

        # Get video document
        try:
            video_id, video_data = await db_service.get_video_document(video_url)
            logger.info(f"[{request_id}] Retrieved video document with ID: {video_id}")
        except Exception as e:
            logger.error(f"[{request_id}] Error retrieving video document: {str(e)}", exc_info=True)
            raise HTTPException(status_code=500, detail=str(e))
        
        if not video_data:
            logger.error(f"[{request_id}] Video not found")
            raise HTTPException(status_code=404, detail="Video not found")
            
        # Verify ownership
        if video_data.get('userId') != decoded_token['uid']:
            logger.error(f"[{request_id}] Permission denied for user {decoded_token['uid']} on video {video_id}")
            raise HTTPException(status_code=403, detail="You don't have permission to analyze this video")

        # Update status to processing
        await db_service.update_video_status(video_id, 'processing')
        logger.info(f"[{request_id}] Updated video {video_id} status to processing")
        
        try:
            # Analyze video content
            logger.info(f"[{request_id}] Starting video content analysis")
            video_analysis = await VideoService.analyze_video_content(video_url)
            logger.info(f"[{request_id}] Video content analysis completed")
            
            # Get health impact analysis
            logger.info(f"[{request_id}] Starting health impact analysis")
            score, reasoning = await HealthService.analyze_health_impact(video_analysis)
            logger.info(f"[{request_id}] Health impact analysis completed")
            
            # Update results
            await db_service.update_video_status(video_id, 'completed', {
                'healthImpactScore': score,
                'healthAnalysis': reasoning
            })
            logger.info(f"[{request_id}] Updated video {video_id} with analysis results")

        except Exception as e:
            logger.error(f"[{request_id}] Analysis failed: {str(e)}", exc_info=True)
            await db_service.update_video_status(video_id, 'failed', {
                'error': str(e)
            })
            raise HTTPException(status_code=500, detail=str(e))
        
        return {
            'success': True,
            'score': score,
            'reasoning': reasoning,
            'videoId': video_id
        }
        
    except HTTPException as he:
        logger.error(f"[{request_id}] HTTP Exception: {str(he)}", exc_info=True)
        raise
    except Exception as e:
        logger.error(f"[{request_id}] Unexpected error: {str(e)}", exc_info=True)
        # Log the full traceback
        logger.error(f"[{request_id}] Traceback:", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/{video_id}/analyze")
async def analyze_video_by_id(
    request: Request,
    db_service: DBServiceDep,
    video_id: str = Path(..., description="The ID of the video to analyze")
) -> Dict:
    """Analyze video content and health impact by ID"""
    try:
        # Auth verification
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            raise HTTPException(status_code=401, detail="No valid authorization header")
            
        token = auth_header.split(' ')[1]
        try:
            decoded_token = auth.verify_id_token(token)
        except Exception as e:
            raise HTTPException(status_code=401, detail="Invalid token")

        # Get video data
        video_data = await db_service.get_video_by_id(video_id)
        if not video_data:
            raise HTTPException(status_code=404, detail="Video not found")
            
        # Verify ownership
        if video_data.get('userId') != decoded_token['uid']:
            raise HTTPException(status_code=403, detail="You don't have permission to analyze this video")

        # Update status to processing
        await db_service.update_video_status(video_id, 'processing')
        
        # Analyze video content
        video_analysis = await VideoService.analyze_video_content(video_data['videoUrl'])
        
        # Get health impact analysis
        score, reasoning = await HealthService.analyze_health_impact(video_analysis)
        
        # Update results
        await db_service.update_video_status(video_id, 'completed', {
            'healthImpactScore': score,
            'healthAnalysis': reasoning
        })
        
        return {
            'success': True,
            'videoId': video_id
        }
    except Exception as e:
        logger.error(f"Error in analyze_video: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/{video_id}/vectorize")
async def vectorize_video(
    request: Request,
    db_service: DBServiceDep,
    video_id: str = Path(..., description="The ID of the video to vectorize")
) -> Dict:
    """Vectorize video metadata and store in Pinecone"""
    try:
        # Auth verification
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            raise HTTPException(status_code=401, detail="No valid authorization header")
            
        token = auth_header.split(' ')[1]
        try:
            decoded_token = auth.verify_id_token(token)
        except Exception as e:
            raise HTTPException(status_code=401, detail="Invalid token")

        # Get video data
        video_data = await db_service.get_video_by_id(video_id)
        if not video_data:
            raise HTTPException(status_code=404, detail="Video not found")

        # Generate and store vector embeddings
        vector_data = await VectorService.vectorize_video(video_data)
        
        # Update video document with vector metadata
        await db_service.update_video_status(video_id, 'vectorized', {
            'vectorId': vector_data['id'],
            'vectorMetadata': vector_data['metadata']
        })

        return {
            'success': True,
            'videoId': video_id,
            'vectorId': vector_data['id']
        }
    except Exception as e:
        logger.error(f"Error vectorizing video: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/{video_id}/update")
async def update_video(
    request: Request,
    db_service: DBServiceDep,
    video_id: str = Path(..., description="The ID of the video to update")
) -> Dict:
    """Update video document"""
    try:
        # Verify authentication
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            raise HTTPException(status_code=401, detail="No valid authorization header")
            
        token = auth_header.split(' ')[1]
        try:
            decoded_token = auth.verify_id_token(token)
        except Exception as e:
            raise HTTPException(status_code=401, detail="Invalid token")

        # Get update data
        update_data = await request.json()
        
        # Update document
        await db_service.update_video(video_id, decoded_token['uid'], update_data)
        
        return {
            'success': True,
            'videoId': video_id
        }
        
    except Exception as e:
        logger.error(f"Error in update_video: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/search")
async def search_videos(
    query: str,
    db_service: DBServiceDep,
    limit: Optional[int] = 10
) -> Dict:
    """Search videos using vector similarity"""
    try:
        # Search vectors in Pinecone
        similar_vectors = await VectorService.search_similar(query, limit)
        
        # Fetch corresponding videos
        videos = await db_service.get_videos_by_ids([v['id'] for v in similar_vectors])
        
        return {
            'success': True,
            'videos': videos,
            'total': len(videos)
        }
    except Exception as e:
        logger.error(f"Error searching videos: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/recommendations")
async def get_recommendations(
    recommendation_service: RecommendationDep,
    user_id: str,
    count: Optional[int] = 10,
    graph_weight: Optional[float] = 0.7
) -> Dict:
    """Get hybrid recommendations combining graph and content similarity"""
    try:
        recommended_videos = await recommendation_service.get_hybrid_recommendations(
            user_id=user_id,
            count=count,
            graph_weight=graph_weight
        )
        
        return {
            'success': True,
            'videos': recommended_videos
        }
    except Exception as e:
        logger.error(f"Error getting recommendations: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e)) 