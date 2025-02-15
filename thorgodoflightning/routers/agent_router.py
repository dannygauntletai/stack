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
import asyncio

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
        
        # Ensure trace_id is in the response
        if 'trace_id' not in result:
            logger.warning("No trace_id found in chat response")
            
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

@router.post("/feedback/{trace_id}")
async def submit_trace_feedback(
    trace_id: str,
    request: Request,
    db_service: DatabaseService = Depends(get_db_service)
) -> Dict:
    """Submit detailed feedback for an agent response"""
    @traceable(project_name="thorgodoflightning")
    async def process_trace_feedback():
        try:
            # Get feedback data from request body
            feedback_data = await request.json()
            
            # Validate required fields
            if 'score' not in feedback_data:
                raise HTTPException(status_code=400, detail="Missing score in feedback")
            
            # Optional fields
            comment = feedback_data.get('comment', '')
            feedback_type = feedback_data.get('type', 'user_feedback')
            metadata = feedback_data.get('metadata', {})
            
            # Submit feedback to LangSmith
            langsmith_client.create_feedback(
                trace_id,
                key=feedback_type,
                score=float(feedback_data['score']),  # Convert to float for consistency
                comment=comment,
                metadata=metadata
            )
            
            # Store feedback in database if needed
            if feedback_data.get('message_id'):
                await db_service.update_message_feedback(
                    feedback_data['message_id'],
                    {
                        'rating': feedback_data['score'],
                        'trace_id': trace_id,
                        'comment': comment,
                        'metadata': metadata
                    }
                )
            
            return {
                'success': True,
                'message': 'Feedback recorded successfully',
                'trace_id': trace_id,
                'feedback_type': feedback_type
            }
            
        except Exception as e:
            logger.error(f"Error submitting trace feedback: {str(e)}")
            raise HTTPException(
                status_code=500, 
                detail=f"Failed to submit feedback: {str(e)}"
            )

    return await process_trace_feedback()

@router.post("/feedback/{trace_id}/rating")
async def submit_rating_feedback(
    trace_id: str,
    rating: float,
    comment: str = None,
    feedback_type: str = "user_rating",
    db_service: DatabaseService = Depends(get_db_service)
) -> Dict:
    """Submit a numerical rating feedback for an agent response"""
    @traceable(project_name="thorgodoflightning")
    async def process_rating_feedback():
        try:
            # Validate rating range (0-1)
            if not 0 <= rating <= 1:
                raise HTTPException(
                    status_code=400, 
                    detail="Rating must be between 0 and 1"
                )
            
            # Submit feedback to LangSmith
            langsmith_client.create_feedback(
                trace_id,
                key=feedback_type,
                score=rating,
                comment=comment
            )
            
            return {
                'success': True,
                'message': 'Rating feedback recorded',
                'trace_id': trace_id,
                'rating': rating
            }
            
        except Exception as e:
            logger.error(f"Error submitting rating feedback: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail=f"Failed to submit rating: {str(e)}"
            )

    return await process_rating_feedback()

@router.post("/feedback/{run_id}/thumbs-up")
async def submit_thumbs_up(
    run_id: str,
    agent_type: str = "chat",
    db_service: DatabaseService = Depends(get_db_service)
) -> Dict:
    """Submit thumbs up feedback for an agent response"""
    logger.info(f"Received thumbs up request for run_id: {run_id}")
    
    async def process_thumbs_up():
        try:
            # Add a small delay to ensure run is posted
            await asyncio.sleep(1)
            
            # Submit feedback to LangSmith
            logger.info(f"Submitting feedback to LangSmith for run_id: {run_id}")
            try:
                langsmith_client.create_feedback(
                    run_id,
                    key="user_rating",
                    score=1.0,
                    comment=f"User gave thumbs up for {agent_type} response"
                )
                logger.info(f"Feedback submitted successfully for run_id: {run_id}")
            except Exception as e:
                logger.error(f"LangSmith error: {str(e)}")
                # Try to get run info to debug
                try:
                    run = langsmith_client.read_run(run_id)
                    logger.info(f"Run info: {run}")
                except Exception as e2:
                    logger.error(f"Could not read run: {str(e2)}")
                raise
            
            return {
                'success': True,
                'message': 'Thumbs up recorded',
                'run_id': run_id,
                'agent_type': agent_type
            }
            
        except Exception as e:
            logger.error(f"Failed to submit thumbs up for run_id {run_id}: {str(e)}", exc_info=True)
            raise HTTPException(
                status_code=500,
                detail=f"Failed to submit thumbs up: {str(e)}"
            )

    return await process_thumbs_up()

@router.post("/feedback/{run_id}/thumbs-down")
async def submit_thumbs_down(
    run_id: str,
    agent_type: str = "chat",
    comment: str = None,
    db_service: DatabaseService = Depends(get_db_service)
) -> Dict:
    """Submit thumbs down feedback for an agent response"""
    async def process_thumbs_down():
        try:
            # Submit feedback to LangSmith
            langsmith_client.create_feedback(
                run_id,
                key="user_rating",
                score=0.0,
                comment=comment or f"User gave thumbs down for {agent_type} response"
            )
            
            return {
                'success': True,
                'message': 'Thumbs down recorded',
                'run_id': run_id,
                'agent_type': agent_type
            }
            
        except Exception as e:
            logger.error(f"Error submitting thumbs down: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail=f"Failed to submit thumbs down: {str(e)}"
            )

    return await process_thumbs_down() 