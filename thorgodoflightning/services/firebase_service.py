import firebase_admin
from firebase_admin import credentials, firestore, storage
import logging
import os
import json
from config import Config

logger = logging.getLogger(__name__)

class FirebaseService:
    _instance = None
    _db = None
    _app = None
    _bucket = None

    @classmethod
    def initialize(cls):
        """Initialize Firebase if not already initialized"""
        if not cls._instance:
            try:
                # In production, ensure we are NOT using the Firestore emulator.
                if Config.is_production():
                    os.environ.pop("FIRESTORE_EMULATOR_HOST", None)
                
                # Get credentials from Config instead of environment
                cred_json = Config.FIREBASE_CREDENTIALS
                if not cred_json:
                    logger.error("Firebase credentials not found in configuration")
                    raise ValueError("Firebase credentials not found in configuration")
                
                try:
                    # Parse the JSON string into a dictionary
                    cred_dict = json.loads(cred_json)
                    cred = credentials.Certificate(cred_dict)
                except json.JSONDecodeError as e:
                    logger.error(f"Failed to parse FIREBASE_CREDENTIALS JSON: {str(e)}")
                    raise ValueError("Invalid FIREBASE_CREDENTIALS JSON format")

                # Initialize Firebase Admin SDK
                cls._instance = firebase_admin.initialize_app(cred, {
                    'storageBucket': Config.FIREBASE_STORAGE_BUCKET
                })
                cls._db = firestore.client()
                
                # Initialize storage bucket
                cls._bucket = storage.bucket()
                
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
        if not cls._app:
            cls.initialize()
        return cls._app

    @classmethod
    def get_bucket(cls):
        """Get the Firebase storage bucket"""
        if not cls._bucket:
            cls.initialize()
        return cls._bucket 