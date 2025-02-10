import os
from dataclasses import dataclass
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

@dataclass
class Config:
    OPENAI_API_KEY: str = os.getenv('OPENAI_API_KEY')
    GOOGLE_APPLICATION_CREDENTIALS: str = os.getenv('GOOGLE_APPLICATION_CREDENTIALS')
    FIREBASE_STORAGE_BUCKET: str = os.getenv('STORAGE_BUCKET_NAME', 'tiktok-18d7a.appspot.com')
    PORT: int = int(os.getenv('PORT', '8000'))
    
    # Add Firestore emulator detection
    USE_FIRESTORE_EMULATOR: bool = os.getenv('USE_FIRESTORE_EMULATOR', '').lower() == 'true'
    FIRESTORE_EMULATOR_HOST: str = os.getenv('FIRESTORE_EMULATOR_HOST', 'localhost:8081')

    @classmethod
    def validate(cls):
        required_vars = ['OPENAI_API_KEY', 'GOOGLE_APPLICATION_CREDENTIALS', 'FIREBASE_STORAGE_BUCKET']
        missing = [var for var in required_vars if not getattr(cls, var)]
        if missing:
            raise ValueError(f"Missing required environment variables: {', '.join(missing)}") 