from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import logging
from routers import health_router, video_router, product_router
from services.firebase_service import FirebaseService

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Firebase before creating FastAPI app
FirebaseService.initialize()

app = FastAPI(title="TikTok Health Analysis API")

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(health_router.router)
app.include_router(video_router.router)
app.include_router(product_router.router)

# Root endpoint
@app.get("/")
async def root():
    return {"message": "TikTok Health Analysis API"} 