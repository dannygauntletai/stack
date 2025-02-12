import firebase_admin
from firebase_admin import credentials, firestore
import logging
import os
from config import Config

logger = logging.getLogger(__name__)

class FirebaseService:
    _instance = None
    _db = None

    @classmethod
    def initialize(cls):
        """Initialize Firebase if not already initialized"""
        if not cls._instance:
            try:
                # Handle credentials in production vs development
                if Config.is_development():
                    cred = credentials.Certificate("service-account.json")
                else:
                    # In production, use JSON string from environment variable
                    import json
                    cred_dict = json.loads(os.getenv('FIREBASE_CREDENTIALS', '{}'))
                    cred = credentials.Certificate(cred_dict)

                # Initialize Firebase Admin SDK
                cls._instance = firebase_admin.initialize_app(cred)
                cls._db = firestore.client()
                
                logger.info("Firebase initialized successfully")
            except Exception as e:
                logger.error(f"Failed to initialize Firebase: {str(e)}", exc_info=True)
                raise

    @classmethod
    def get_db(cls) -> firestore.Client:
        """Get Firestore client, initializing if necessary"""
        if not cls._instance:
            cls.initialize()
        return cls._db

    @classmethod
    def get_app(cls):
        """Get Firebase app instance, initializing if necessary"""
        if not cls._instance:
            cls.initialize()
        return cls._instance 