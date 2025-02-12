from fastapi import APIRouter, HTTPException, Depends
from typing import Dict
from services.agents.agent_router import AgentRouter
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
    db_service: DatabaseService = Depends(get_db_service)
) -> Dict:
    """Research a product using the research agent"""
    try:
        # We're passing the product ID and title directly since that's what our agent needs
        product_data = {
            'id': product_id,
            'title': product_id,  # We can use the ID as title for now since we don't store products
            'productUrl': ''  # Required by agent but not used for research
        }
            
        # Initialize agent router
        agent_router = AgentRouter(db_service)
        
        # Process research request
        result = await agent_router.route_request("research", product_data)
        
        return result  # This already has the format we want
        
    except Exception as e:
        logger.error(f"Error researching product: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e)) 