from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import logging
from routers import health_router, video_router, product_router
from services.firebase_service import FirebaseService
from config import Config

# Configure logging
logging.basicConfig(
    level=logging.DEBUG if Config.is_debug() else logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize Firebase before creating FastAPI app
FirebaseService.initialize()

# Create FastAPI app with environment-specific settings
app = FastAPI(
    title="TikTok Health Analysis API",
    description="API for analyzing TikTok videos for health impact",
    version="1.0.0",
    debug=Config.is_debug()
)

# CORS configuration
origins = ["*"] if Config.is_development() else [
    "https://stack-pjz5.onrender.com",
    "https://tiktok-18d7a.web.app",  # Add your frontend domain
    "https://tiktok-18d7a.firebaseapp.com"  # Add your firebase hosting domain
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
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
    return {
        "message": "TikTok Health Analysis API",
        "environment": Config.ENVIRONMENT,
        "version": "1.0.0"
    }

# Startup event
@app.on_event("startup")
async def startup_event():
    logger.info(f"Starting application in {Config.ENVIRONMENT} environment")
    Config.validate()

# Shutdown event
@app.on_event("shutdown")
async def shutdown_event():
    logger.info("Shutting down application") 