import os
from dotenv import load_dotenv
from pathlib import Path

# Load local .env file if it exists
env_path = Path(__file__).parent / '.env'
if env_path.exists():
    load_dotenv(dotenv_path=env_path)

class Config:
    """Configuration management class"""
    
    @classmethod
    def get_env(cls, key: str, default: str = None) -> str:
        """Get environment variable with fallback to default."""
        return os.environ.get(key, default)
    
    # Environment variables
    OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')
    GOOGLE_CLOUD_PROJECT = os.getenv('GOOGLE_CLOUD_PROJECT')
    FIREBASE_STORAGE_BUCKET = os.getenv('FIREBASE_STORAGE_BUCKET')
    FIREBASE_CLIENT_EMAIL = os.getenv('FIREBASE_CLIENT_EMAIL')
    FIREBASE_PRIVATE_KEY = os.getenv('FIREBASE_PRIVATE_KEY')
    GOOGLE_APPLICATION_CREDENTIALS = str(Path(__file__).parent / 'service-account.json')
    
    @classmethod
    def validate(cls):
        """Validate all required environment variables are set."""
        required_vars = [
            'OPENAI_API_KEY',
            'GOOGLE_CLOUD_PROJECT',
            'FIREBASE_STORAGE_BUCKET',
            'FIREBASE_CLIENT_EMAIL',
            'FIREBASE_PRIVATE_KEY'
        ]
        
        missing = [var for var in required_vars if not os.getenv(var)]
        
        if missing:
            raise EnvironmentError(
                f"Missing required environment variables: {', '.join(missing)}"
            )
        
        # Validate service account file exists
        if not Path(cls.GOOGLE_APPLICATION_CREDENTIALS).exists():
            raise FileNotFoundError(
                f"Service account file not found at: {cls.GOOGLE_APPLICATION_CREDENTIALS}"
            ) 