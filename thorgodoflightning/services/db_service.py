from firebase_admin import firestore
from typing import Dict, Any, Tuple, Optional, List
import traceback

class DatabaseService:
    def __init__(self, db: firestore.Client):
        self.db = db

    async def get_video_document(self, video_url: str) -> Tuple[str, Optional[Dict]]:
        try:
            query = self.db.collection('videos').where('videoUrl', '==', video_url)
            docs = query.get()
            docs_list = list(docs)
            
            if not docs_list:
                return None, None
                
            video_doc = docs_list[0]
            return video_doc.id, self._serialize_firestore_doc(video_doc.to_dict())
        except Exception as e:
            raise ValueError(f"Failed to fetch video document: {str(e)}")

    async def update_video_status(self, video_id: str, status: str, data: Dict = None):
        """Update video status and additional data"""
        try:
            doc_ref = self.db.collection('videos').document(video_id)
            
            # Prepare update data
            update_data = {
                'analysisStatus': status,
                'updatedAt': firestore.SERVER_TIMESTAMP
            }
            
            if data:
                # Ensure nested objects are properly structured
                if 'healthAnalysis' in data:
                    update_data['healthAnalysis'] = data['healthAnalysis']
                if 'healthImpactScore' in data:
                    update_data['healthImpactScore'] = data['healthImpactScore']
                if 'vectorId' in data:
                    update_data['vectorId'] = data['vectorId']
                if 'vectorMetadata' in data:
                    update_data['vectorMetadata'] = data['vectorMetadata']
            
            # Update document
            doc_ref.update(update_data)
            
            print(f"<THOR_DEBUG> Updated video {video_id} with status {status}")
            if data:
                print(f"<THOR_DEBUG> Updated data: {update_data}")
                
        except Exception as e:
            print(f"<THOR_DEBUG> Error updating video: {str(e)}")
            raise ValueError(f"Failed to update video status: {str(e)}")

    async def check_connection(self):
        """Test database connection"""
        try:
            self.db.collection('videos').limit(1).get()
        except Exception as e:
            raise ValueError(f"Database connection failed: {str(e)}")

    async def update_video(self, video_id: str, user_id: str, data: Dict):
        """Update video document with ownership verification"""
        try:
            doc_ref = self.db.collection('videos').document(video_id)
            doc = doc_ref.get()
            
            if not doc.exists:
                raise ValueError("Video not found")
                
            video_data = doc.to_dict()
            if video_data.get('userId') != user_id:
                raise ValueError("You don't have permission to update this video")
                
            doc_ref.update(data)
        except Exception as e:
            raise ValueError(f"Failed to update video: {str(e)}")

    @staticmethod
    def _serialize_firestore_doc(doc_data: dict) -> dict:
        serialized = {}
        for key, value in doc_data.items():
            if hasattr(value, 'timestamp'):
                serialized[key] = value.isoformat()
            else:
                serialized[key] = value
        return serialized 

    async def get_user_recent_videos(self, user_id: str, limit: int = 10) -> List[Dict]:
        """Get user's recently interacted videos"""
        try:
            # Query user interactions collection
            interactions = self.db.collection('user_interactions')\
                .document(user_id)\
                .collection('videos')\
                .order_by('lastInteraction', direction=firestore.Query.DESCENDING)\
                .limit(limit)
            
            docs = interactions.get()
            video_ids = [doc.id for doc in docs]
            
            if not video_ids:
                return []
            
            return await self.get_videos_by_ids(video_ids)
        except Exception as e:
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
            raise ValueError(f"Failed to get graph recommendations: {str(e)}")

    async def get_video_by_id(self, video_id: str) -> Optional[Dict]:
        """Get video document by ID"""
        try:
            doc_ref = self.db.collection('videos').document(video_id)
            doc = doc_ref.get()
            
            if not doc.exists:
                return None
                
            return self._serialize_firestore_doc(doc.to_dict())
        except Exception as e:
            print(f"<THOR_DEBUG> Error fetching video: {str(e)}")
            print("<THOR_DEBUG> Error traceback: ", traceback.format_exc())
            raise ValueError(f"Failed to fetch video: {str(e)}")

    async def get_videos_by_ids(self, video_ids: List[str]) -> List[Dict]:
        """Get multiple video documents by their IDs"""
        try:
            docs = []
            # Firestore limits batched reads to 10 documents
            for i in range(0, len(video_ids), 10):
                batch = video_ids[i:i + 10]
                refs = [self.db.collection('videos').document(vid) for vid in batch]
                batch_docs = self.db.get_all(refs)
                docs.extend([doc for doc in batch_docs if doc.exists])
            
            return [self._serialize_firestore_doc(doc.to_dict()) for doc in docs]
        except Exception as e:
            raise ValueError(f"Failed to fetch videos: {str(e)}") 