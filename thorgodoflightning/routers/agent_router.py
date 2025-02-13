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