from typing import Dict, List
from firebase_admin import firestore
import logging
from services.vector_service import VectorService
from services.db_service import DatabaseService

logger = logging.getLogger(__name__)

class RecommendationService:
    def __init__(self, db: firestore.Client):
        self.db = db
        self.db_service = DatabaseService(db)

    async def get_videos_by_ids(self, video_ids: List[str]) -> List[Dict]:
        """Get videos by their IDs"""
        return await self.db_service.get_videos_by_ids(video_ids)

    async def get_user_recent_videos(self, user_id: str, limit: int = 10) -> List[Dict]:
        """Get user's recently interacted videos"""
        try:
            # Use db_service for video fetching
            interactions = self.db.collection('user_interactions')\
                .document(user_id)\
                .collection('videos')\
                .order_by('lastInteraction', direction=firestore.Query.DESCENDING)\
                .limit(limit)\
                .get()
            
            video_ids = [doc.id for doc in interactions]
            if not video_ids:
                return []
            
            return await self.db_service.get_videos_by_ids(video_ids)
        except Exception as e:
            logger.error(f"Error getting recent videos: {str(e)}")
            raise ValueError(f"Failed to get user recent videos: {str(e)}")

    async def get_graph_recommendations(self, user_id: str, limit: int = 10) -> List[str]:
        """Get recommendations based on interaction graph"""
        try:
            # Get user's interactions
            interactions = self.db.collection('user_interactions')\
                .document(user_id)\
                .collection('videos')\
                .order_by('interactionScore', direction=firestore.Query.DESCENDING)\
                .limit(100)\
                .get()
            
            # Get similar users based on interaction overlap
            user_scores = {}
            for doc in interactions:
                video_id = doc.id
                similar_users = self.db.collection('videos')\
                    .document(video_id)\
                    .collection('interactions')\
                    .order_by('score', direction=firestore.Query.DESCENDING)\
                    .limit(20)\
                    .get()
                
                for user_doc in similar_users:
                    if user_doc.id != user_id:
                        user_scores[user_doc.id] = user_scores.get(user_doc.id, 0) + user_doc.get('score', 0)
                
            # Get videos from similar users
            recommended_videos = set()
            for similar_user_id in sorted(user_scores, key=user_scores.get, reverse=True)[:5]:
                user_videos = self.db.collection('user_interactions')\
                    .document(similar_user_id)\
                    .collection('videos')\
                    .order_by('interactionScore', direction=firestore.Query.DESCENDING)\
                    .limit(20)\
                    .get()
                
                for doc in user_videos:
                    recommended_videos.add(doc.id)
                    if len(recommended_videos) >= limit:
                        break
                
                if len(recommended_videos) >= limit:
                    break
            
            return list(recommended_videos)[:limit]
        except Exception as e:
            logger.error(f"Failed to get graph recommendations: {str(e)}", exc_info=True)
            raise ValueError(f"Failed to get graph recommendations: {str(e)}")

    async def get_hybrid_recommendations(
        self,
        user_id: str,
        count: int = 10,
        graph_weight: float = 0.7
    ) -> List[Dict]:
        """Get hybrid recommendations combining graph and content similarity"""
        try:
            # Get user's recent interactions
            recent_videos = await self.get_user_recent_videos(user_id)
            if not recent_videos:
                return []
                
            # Get similar videos based on most recent interaction
            recent_video_id = recent_videos[0]['id']
            similar_videos = await VectorService.search_similar(recent_video_id, limit=count)
            
            # Get graph-based recommendations
            graph_videos = await self.get_graph_recommendations(user_id, count)
            
            # Combine recommendations with weights
            final_scores = {}
            
            # Add graph-based scores
            for i, video_id in enumerate(graph_videos):
                score = (count - i) / count * graph_weight
                final_scores[video_id] = final_scores.get(video_id, 0) + score
                
            # Add similarity-based scores
            embedding_weight = 1.0 - graph_weight
            for video in similar_videos:
                video_id = video['id']
                final_scores[video_id] = final_scores.get(video_id, 0) + (embedding_weight * video['score'])
                
            # Sort and get top recommendations
            recommended_ids = sorted(final_scores.items(), key=lambda x: x[1], reverse=True)[:count]
            return await self.get_videos_by_ids([vid for vid, _ in recommended_ids])
            
        except Exception as e:
            logger.error(f"Failed to get hybrid recommendations: {str(e)}", exc_info=True)
            raise ValueError(f"Failed to get hybrid recommendations: {str(e)}") 