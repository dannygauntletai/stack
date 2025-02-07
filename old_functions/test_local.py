import asyncio
import json
import logging
from dataclasses import dataclass
from typing import Optional, Dict

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class Request:
    """Mock Firebase Functions request."""
    _json: Dict
    
    @property
    def json(self) -> Dict:
        return self._json

async def main():
    """Run test analysis."""
    from main import analyze_video_health
    
    # Create test request with just the video URL
    request = Request({
        'videoUrl': 'gs://tiktok-18d7a.firebasestorage.app/videos/C1DB38BF-1919-4CAF-A91A-0BAD704D5A45.mp4'
    })
    
    try:
        # Run analysis
        logger.info("Starting video analysis...")
        result = await analyze_video_health(request)
        
        # Print results
        print("\n=== Analysis Results ===")
        print(json.dumps(result, indent=2))
        
    except Exception as e:
        logger.error(f"Test failed: {str(e)}", exc_info=True)

if __name__ == "__main__":
    asyncio.run(main()) 