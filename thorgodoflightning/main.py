from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import logging
from routers import health_router, video_router, product_router
from services.firebase_service import FirebaseService
from config import Config

# Configure logging
logging.basicConfig(
    level=logging.DEBUG if Config.is_debug() else logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),  # Log to console
        logging.FileHandler('app.log')  # Log to file
    ]
)
logger = logging.getLogger(__name__)

# Initialize Firebase before creating FastAPI app
try:
    FirebaseService.initialize()
    logger.info("Firebase initialization successful")
except Exception as e:
    logger.error(f"Firebase initialization failed: {str(e)}", exc_info=True)
    raise

# Create FastAPI app
app = FastAPI(
    title="TikTok Health Analysis API",
    description="API for analyzing TikTok videos for health impact",
    version="1.0.0",
    debug=Config.is_debug()
)

# CORS configuration
origins = ["*"] if Config.is_development() else [
    Config.BASE_URL,
    "https://tiktok-18d7a.web.app",
    "https://tiktok-18d7a.firebaseapp.com"
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

@app.get("/")
async def root():
    logger.info("Root endpoint accessed")
    return {
        "message": "TikTok Health Analysis API",
        "environment": Config.ENVIRONMENT,
        "version": "1.0.0"
    }

@app.on_event("startup")
async def startup_event():
    logger.info(f"Starting application in {Config.ENVIRONMENT} environment")
    try:
        Config.validate()
        logger.info("Configuration validation successful")
    except Exception as e:
        logger.error(f"Configuration validation failed: {str(e)}", exc_info=True)
        raise

@app.on_event("shutdown")
async def shutdown_event():
    logger.info("Shutting down application") 