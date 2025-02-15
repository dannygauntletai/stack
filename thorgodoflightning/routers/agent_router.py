from fastapi import APIRouter, HTTPException, Depends, Request
from typing import Dict
from services.agent_service import AgentService
from services.db_service import DatabaseService
from dependencies import get_db_service
import logging
from langchain.callbacks.manager import tracing_v2_enabled
from config import Config
import time
import os
from langsmith import traceable, Client

router = APIRouter(
    prefix="/agents",
    tags=["agents"]
)

logger = logging.getLogger(__name__)

# Initialize LangSmith client
langsmith_client = Client()

@router.post("/research/{product_id}")
async def research_product(
    product_id: str,
    request: Request,
    db_service: DatabaseService = Depends(get_db_service)
) -> Dict:
    """Research a product using the research agent"""
    try:
        # Get the full product data from request body
        product_data = await request.json()
        logger.debug(f"Received product data: {product_data}")
            
        # Initialize agent service
        agent_service = AgentService(db_service)
        
        # Process research request with full product data
        result = await agent_service.route_request("research", product_data)
        
        return result
        
    except Exception as e:
        logger.error(f"Error researching product: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/chat")
async def chat(
    request: Request,
    db_service: DatabaseService = Depends(get_db_service)
) -> Dict:
    """Process chat messages using chat agent"""
    try:
        # Get chat data from request body
        chat_data = await request.json()
        
        # Initialize agent service
        agent_service = AgentService(db_service)
        
        # Process chat request
        result = await agent_service.route_request("chat", chat_data)
        
        return result
        
    except Exception as e:
        logger.error(f"Error in chat endpoint: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/chat/feedback/{message_id}")
async def submit_feedback(
    message_id: str,
    feedback: Dict,
    db_service: DatabaseService = Depends(get_db_service)
) -> Dict:
    """Submit feedback for a chat message"""
    @traceable(project_name="thorgodoflightning")
    async def process_feedback():
        if 'rating' not in feedback:
            raise HTTPException(status_code=400, detail="Missing rating in feedback")
        
        # Update message in database
        await db_service.update_message_feedback(message_id, feedback)
        
        # Add metadata about the feedback
        if trace_id := feedback.get('trace_id'):
            return {
                "message_id": message_id,
                "feedback_rating": feedback['rating'],
                "feedback_comments": feedback.get('comments', ''),
                "original_trace_id": trace_id
            }
        
        return {
            'success': True,
            'message': 'Feedback recorded successfully'
        }

    try:
        result = await process_feedback()
        return result
    except Exception as e:
        logger.error(f"Error submitting feedback: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/chat/feedback/{message_id}/thumbs-up")
async def submit_positive_feedback(
    message_id: str,
    trace_id: str,
    db_service: DatabaseService = Depends(get_db_service)
) -> Dict:
    """Submit positive feedback for a chat message"""
    @traceable(project_name="thorgodoflightning")
    async def process_positive_feedback():
        try:
            # Update message feedback in database
            await db_service.update_message_feedback(message_id, {
                'rating': 1,
                'trace_id': trace_id
            })
            
            # Submit feedback to LangSmith
            langsmith_client.create_feedback(
                trace_id,
                "user_rating",
                score=1.0,  # 1.0 for thumbs up
                comment="User gave thumbs up"
            )
            
            return {
                'success': True,
                'message': 'Positive feedback recorded'
            }
        except Exception as e:
            logger.error(f"Error submitting positive feedback: {str(e)}")
            raise

    return await process_positive_feedback()

@router.post("/chat/feedback/{message_id}/thumbs-down")
async def submit_negative_feedback(
    message_id: str,
    trace_id: str,
    comment: str = None,
    db_service: DatabaseService = Depends(get_db_service)
) -> Dict:
    """Submit negative feedback for a chat message"""
    @traceable(project_name="thorgodoflightning")
    async def process_negative_feedback():
        try:
            # Update message feedback in database
            await db_service.update_message_feedback(message_id, {
                'rating': -1,
                'trace_id': trace_id,
                'comment': comment
            })
            
            # Submit feedback to LangSmith
            langsmith_client.create_feedback(
                trace_id,
                "user_rating",
                score=0.0,  # 0.0 for thumbs down
                comment=comment or "User gave thumbs down"
            )
            
            return {
                'success': True,
                'message': 'Negative feedback recorded'
            }
        except Exception as e:
            logger.error(f"Error submitting negative feedback: {str(e)}")
            raise

    return await process_negative_feedback() 