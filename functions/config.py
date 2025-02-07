import os
from dataclasses import dataclass

@dataclass
class Config:
    OPENAI_API_KEY: str = os.getenv('OPENAI_API_KEY')
    GOOGLE_APPLICATION_CREDENTIALS: str = os.getenv('GOOGLE_APPLICATION_CREDENTIALS', './service-account.json')
    FIREBASE_STORAGE_BUCKET: str = os.getenv('FIREBASE_STORAGE_BUCKET', 'tiktok-18d7a.appspot.com')

    @classmethod
    def validate(cls):
        # Only validate when not in function discovery mode
        if os.getenv('FUNCTION_TARGET'):
            if not cls.OPENAI_API_KEY:
                raise ValueError("OPENAI_API_KEY is required")
            if not cls.GOOGLE_APPLICATION_CREDENTIALS:
                raise ValueError("GOOGLE_APPLICATION_CREDENTIALS is required")
            if not cls.FIREBASE_STORAGE_BUCKET:
                raise ValueError("FIREBASE_STORAGE_BUCKET is required") 