import os
from dataclasses import dataclass
from dotenv import load_dotenv

# Load environment variables only in development
if os.getenv('ENVIRONMENT') != 'production':
    load_dotenv()

@dataclass
class Config:
    # Environment
    ENVIRONMENT: str = os.getenv('ENVIRONMENT', 'development')
    
    # OpenAI
    OPENAI_API_KEY: str = os.getenv('OPENAI_API_KEY')
    
    # Google Cloud
    PROJECT_ID: str = os.getenv('PROJECT_ID')
    GOOGLE_APPLICATION_CREDENTIALS: str = os.getenv('GOOGLE_APPLICATION_CREDENTIALS')
    PROJECT_NAME: str = os.getenv('PROJECT_NAME')
    
    # Firebase
    FIREBASE_STORAGE_BUCKET: str = os.getenv('STORAGE_BUCKET_NAME')
    SERVICE_ACCOUNT_EMAIL: str = os.getenv('SERVICE_ACCOUNT_EMAIL')
    
    # Google Cloud API
    GOOGLE_CLOUD_VISION_API_KEY: str = os.getenv('GOOGLE_CLOUD_VISION_API_KEY')
    GOOGLE_CLOUD_VIDEO_INTELLIGENCE_API_KEY: str = os.getenv('GOOGLE_CLOUD_VIDEO_INTELLIGENCE_API_KEY')
    
    # Model
    MODEL_PATH: str = os.getenv('MODEL_PATH')
    
    # Pinecone
    PINECONE_API_KEY: str = os.getenv('PINECONE_API_KEY')
    PINECONE_INDEX_NAME: str = os.getenv('PINECONE_INDEX_NAME')
    PINECONE_PROJECT_ID: str = os.getenv('PINECONE_PROJECT_ID')
    PINECONE_ENVIRONMENT: str = os.getenv('PINECONE_ENVIRONMENT')
    
    # Server
    PORT: int = int(os.getenv('PORT', '8000'))
    
    # Emulator Settings - only used in development
    USE_FIRESTORE_EMULATOR: bool = os.getenv('ENVIRONMENT') != 'production' and os.getenv('FUNCTIONS_EMULATOR', '').lower() == 'true'
    FIRESTORE_EMULATOR_HOST: str = os.getenv('FIRESTORE_EMULATOR_HOST', 'localhost:8081') if USE_FIRESTORE_EMULATOR else None

    @classmethod
    def is_development(cls) -> bool:
        return cls.ENVIRONMENT != 'production'

    @classmethod
    def validate(cls):
        """Validate all required environment variables are set"""
        required_vars = {
            'OpenAI': ['OPENAI_API_KEY'],
            'Google Cloud': [
                'PROJECT_ID',
                'GOOGLE_APPLICATION_CREDENTIALS',
                'GOOGLE_CLOUD_VISION_API_KEY',
                'GOOGLE_CLOUD_VIDEO_INTELLIGENCE_API_KEY'
            ],
            'Firebase': [
                'FIREBASE_STORAGE_BUCKET',
                'SERVICE_ACCOUNT_EMAIL'
            ],
            'Pinecone': [
                'PINECONE_API_KEY',
                'PINECONE_INDEX_NAME',
                'PINECONE_PROJECT_ID',
                'PINECONE_ENVIRONMENT'
            ]
        }
        
        missing = {}
        for category, vars in required_vars.items():
            missing_in_category = [var for var in vars if not getattr(cls, var)]
            if missing_in_category:
                missing[category] = missing_in_category
                
        if missing:
            error_msg = "Missing required environment variables:\n"
            for category, vars in missing.items():
                error_msg += f"\n{category}:\n" + "\n".join(f"- {var}" for var in vars)
            raise ValueError(error_msg) 