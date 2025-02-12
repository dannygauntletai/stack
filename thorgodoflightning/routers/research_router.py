from fastapi import APIRouter, HTTPException, BackgroundTasks
from typing import List, Dict
import logging
from services.research_service import ResearchService
from datetime import datetime
import uuid

router = APIRouter(
    prefix="/research",
    tags=["research"]
)

logger = logging.getLogger(__name__)

@router.post("/compare-products")
async def start_product_comparison(products: List[Dict], background_tasks: BackgroundTasks):
    """Start a product comparison research task"""
    try:
        research_id = str(uuid.uuid4())
        
        # Start research in background
        background_tasks.add_task(
            ResearchService.research_products,
            research_id=research_id,
            products=products
        )
        
        return {
            "success": True,
            "research_id": research_id,
            "status": "started",
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        logger.error(f"Failed to start research: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/status/{research_id}")
async def get_research_status(research_id: str):
    """Get the status of a research task"""
    try:
        status = await ResearchService.get_research_status(research_id)
        return {
            "success": True,
            "research_id": research_id,
            "status": status
        }
    except Exception as e:
        logger.error(f"Failed to get research status: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e)) 