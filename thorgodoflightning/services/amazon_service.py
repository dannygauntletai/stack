from typing import Dict, List
import requests
import logging
import os
from dotenv import load_dotenv
import traceback

# Load environment variables from .env file
load_dotenv()

logger = logging.getLogger(__name__)

class Product:
    def __init__(self, asin: str, title: str, image_url: str, price: Dict, rating: float, review_count: int, product_url: str, is_prime: bool):
        self.asin = asin
        self.title = title
        self.image_url = image_url
        self.price = price
        self.rating = rating
        self.review_count = review_count
        self.product_url = product_url
        self.is_prime = is_prime

    def __repr__(self):
        return f"Product(asin={self.asin}, title={self.title}, price={self.price}, rating={self.rating}, review_count={self.review_count})"

class AmazonService:
    def __init__(self):
        self.api_key = os.getenv('RAINFOREST_API_KEY')
        self.endpoint = "https://api.rainforestapi.com/request"

    async def get_supplement_products(self, supplement: Dict) -> List[Dict]:
        """
        Get Amazon products for a supplement recommendation using Rainforest API.
        
        Args:
            supplement (Dict): Supplement recommendation containing name, dosage, etc.
            
        Returns:
            List[Dict]: List of Amazon products with details
        """
        try:
            search_term = f"{supplement['name']} supplement {supplement.get('dosage', '')}"
            logger.info(f"[Rainforest API] Search term: {search_term}")

            # Build the request parameters
            params = {
                'api_key': self.api_key,
                'amazon_domain': 'amazon.com',
                'search_term': search_term,
                'type': 'search'
            }

            # Log the request details
            logger.info(f"[Rainforest API] Request URL: {self.endpoint}")
            logger.info(f"[Rainforest API] Request Params: {params}")

            # Make the request
            response = requests.get(
                self.endpoint,
                params=params,
                timeout=30  # Increased timeout for Rainforest API
            )

            logger.info(f"[Rainforest API] Response Status: {response.status_code}")
            
            if response.status_code == 200:
                data = response.json()
                search_results = data.get('search_results', [])
                # Limit to top 3 results
                products = search_results[:3]
                logger.info(f"[Rainforest API] Found {len(products)} products")
                return self._parse_products(products)
            else:
                logger.error(f"[Rainforest API] Error response: {response.text}")
                return []

        except Exception as e:
            logger.error(f"[Rainforest API] Exception: {str(e)}", exc_info=True)
            logger.error(f"[Rainforest API] Traceback: {traceback.format_exc()}")
            return []

    def _parse_products(self, products: List[Dict]) -> List[Product]:
        """Parse the product data from Rainforest API response."""
        parsed_products = []
        for item in products:
            product = Product(
                asin=item.get('asin'),
                title=item.get('title'),
                image_url=item.get('image'),
                price=self._extract_price(item),
                rating=item.get('rating'),
                review_count=item.get('ratings_total'),
                product_url=item.get('link'),
                is_prime=item.get('is_prime', False)
            )
            parsed_products.append(product)
        return parsed_products

    def _extract_price(self, item: Dict) -> Dict:
        """Extract price information from Rainforest API item"""
        price = item.get('price', {})
        if not price:
            return None
            
        return {
            'amount': price.get('value'),
            'currency': price.get('currency'),
            'display_amount': price.get('raw')
        }