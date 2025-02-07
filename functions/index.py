import asyncio
from firebase_functions import https_fn
from main import analyze_video_health

@https_fn.on_request()
def analyze_health(req: https_fn.Request) -> https_fn.Response:
    """HTTP Cloud Function entry point."""
    try:
        # Run the async function in the event loop
        result = asyncio.run(analyze_video_health(req))
        return https_fn.Response(result)
    except Exception as e:
        return https_fn.Response(
            {"error": str(e)}, 
            status=500
        ) 