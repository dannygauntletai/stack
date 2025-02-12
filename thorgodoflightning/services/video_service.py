from google.cloud import videointelligence_v1 as videointelligence
from typing import Dict
import json
import traceback
import logging
from google.oauth2 import service_account
import os
from config import Config

logger = logging.getLogger(__name__)

class VideoService:
    @staticmethod
    async def analyze_video_content(video_url: str) -> Dict:
        logger.info(f"Starting video content analysis for URL: {video_url}")
        print(f"<THOR_DEBUG> Processing video URL: {video_url}")
        
        try:
            # Get credentials from Config
            credentials = service_account.Credentials.from_service_account_info(
                json.loads(Config.FIREBASE_CREDENTIALS),
                scopes=['https://www.googleapis.com/auth/cloud-platform']
            )
            
            # Create Video Intelligence client with explicit credentials
            video_client = videointelligence.VideoIntelligenceServiceClient(
                credentials=credentials
            )
            
            if not video_url.startswith('gs://'):
                logger.error(f"Invalid video URL format: {video_url}")
                raise ValueError("Invalid video URL format")
                
            features = [
                videointelligence.Feature.LABEL_DETECTION,
                videointelligence.Feature.EXPLICIT_CONTENT_DETECTION
            ]
            
            request = videointelligence.AnnotateVideoRequest(
                input_uri=video_url,
                features=features
            )
            
            logger.info("Sending request to Video Intelligence API")
            try:
                operation = video_client.annotate_video(request)
                result = operation.result(timeout=480)
                logger.info("Received Video Intelligence results")
            except Exception as e:
                logger.error(f"Video Intelligence API error: {str(e)}", exc_info=True)
                raise

            # Create the analysis dictionary
            video_analysis = {
                'labels': [],
                'explicit_content': [],
                'content_categories': {
                    'primary_category': '',
                    'activities': [],
                    'environment': '',
                    'objects': []
                }
            }
            
            # Process labels
            activity_keywords = {
                'exercise': ['workout', 'exercise', 'fitness', 'training', 'sports', 'running', 'yoga', 'gym'],
                'study': ['reading', 'studying', 'learning', 'education', 'books', 'writing', 'school'],
                'food': ['cooking', 'food', 'meal', 'eating', 'nutrition', 'diet', 'recipe'],
                'wellness': ['meditation', 'relaxation', 'wellness', 'health', 'spa', 'massage', 'mindfulness'],
                'outdoor': ['nature', 'hiking', 'camping', 'garden', 'outdoor', 'park']
            }
            
            detected_activities = set()
            
            for annotation in result.annotation_results:
                if hasattr(annotation, 'segment_label_annotations'):
                    # Process and categorize labels
                    for label in annotation.segment_label_annotations:
                        label_info = {
                            'description': label.entity.description,
                            'confidence': label.segments[0].confidence if label.segments else 0.0
                        }
                        video_analysis['labels'].append(label_info)
                        
                        # Categorize label
                        label_lower = label.entity.description.lower()
                        for category, keywords in activity_keywords.items():
                            if any(keyword in label_lower for keyword in keywords):
                                detected_activities.add(category)
                                video_analysis['content_categories']['activities'].append({
                                    'category': category,
                                    'label': label.entity.description,
                                    'confidence': label.segments[0].confidence if label.segments else 0.0
                                })
                
                # Process explicit content
                if hasattr(annotation, 'explicit_annotation'):
                    video_analysis['explicit_content'] = [
                        {
                            'timestamp': frame.time_offset.seconds,
                            'likelihood': frame.pornography_likelihood.name
                        }
                        for frame in annotation.explicit_annotation.frames
                    ]
            
            # Determine primary category based on frequency and confidence
            if detected_activities:
                activity_scores = {}
                for activity in video_analysis['content_categories']['activities']:
                    category = activity['category']
                    activity_scores[category] = activity_scores.get(category, 0) + activity['confidence']
                
                video_analysis['content_categories']['primary_category'] = max(
                    activity_scores.items(),
                    key=lambda x: x[1]
                )[0]
            
            # Set environment based on existing labels
            video_analysis['content_categories']['environment'] = VideoService._categorize_environment(
                video_analysis['labels']
            )
            
            print("<THOR_DEBUG> Enhanced analysis complete")
            print(f"<THOR_DEBUG> Primary category: {video_analysis['content_categories']['primary_category']}")
            print(f"<THOR_DEBUG> Detected activities: {detected_activities}")
            print(f"<THOR_DEBUG> Analysis result: {json.dumps(video_analysis, indent=2)}")
            
            return video_analysis
                
        except Exception as e:
            print(f"<THOR_DEBUG> ERROR in video analysis: {str(e)}")
            print(f"<THOR_DEBUG> Error traceback: ", traceback.format_exc())
            raise ValueError(f"Video analysis failed: {str(e)}")

    @staticmethod
    def _categorize_environment(labels: list) -> str:
        """Categorize the environment based on labels."""
        environment_keywords = {
            'indoor': ['room', 'indoor', 'house', 'building', 'gym', 'office'],
            'outdoor': ['nature', 'outdoor', 'park', 'garden', 'street', 'forest'],
            'urban': ['city', 'urban', 'street', 'building'],
            'natural': ['nature', 'forest', 'beach', 'mountain', 'park']
        }
        
        environment_scores = {env: 0 for env in environment_keywords}
        
        for label in labels:
            label_text = label['description'].lower()
            for env, keywords in environment_keywords.items():
                if any(keyword in label_text for keyword in keywords):
                    environment_scores[env] += label['confidence']
        
        if any(environment_scores.values()):
            return max(environment_scores.items(), key=lambda x: x[1])[0]
        return 'unknown'