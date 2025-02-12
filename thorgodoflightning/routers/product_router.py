from fastapi import APIRouter, HTTPException
from typing import Dict
from services.amazon_service import AmazonService
import logging

router = APIRouter(
    prefix="/products",
    tags=["products"]
)

logger = logging.getLogger(__name__)

@router.post("/supplements")
async def get_supplement_products(supplement: Dict) -> Dict:
    """Get Amazon products for a supplement recommendation"""
    try:
        amazon_service = AmazonService()
        products = await amazon_service.get_supplement_products(supplement)
        
        return {
            'success': True,
            'products': [vars(product) for product in products],
            'supplement': supplement
        }
    except Exception as e:
        logger.error(f"Error getting supplement products: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))