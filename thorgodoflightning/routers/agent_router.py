from fastapi import APIRouter, HTTPException, Depends, Request
from typing import Dict
from services.agent_service import AgentService
from services.db_service import DatabaseService
from dependencies import get_db_service
import logging

router = APIRouter(
    prefix="/agents",
    tags=["agents"]
)

logger = logging.getLogger(__name__)

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
        
        # Validate required fields
        if not all(k in chat_data for k in ['content', 'type', 'session_id']):
            raise HTTPException(status_code=400, detail="Missing required fields")
            
        # Initialize agent service
        agent_service = AgentService(db_service)
        
        # Process chat request
        result = await agent_service.route_request("chat", chat_data)
        
        return result
        
    except Exception as e:
        logger.error(f"Error in chat endpoint: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e)) 