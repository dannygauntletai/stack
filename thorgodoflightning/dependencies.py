from fastapi import Depends
from services.firebase_service import FirebaseService
from services.db_service import DatabaseService
from services.recommendation_service import RecommendationService
from typing import Annotated

def get_db():
    return FirebaseService.get_db()

def get_db_service(db=Depends(get_db)) -> DatabaseService:
    return DatabaseService(db)

def get_recommendation_service(db=Depends(get_db)) -> RecommendationService:
    return RecommendationService(db) 