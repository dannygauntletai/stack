from google.cloud import videointelligence_v1 as videointelligence
from typing import Dict
import json
import traceback
import logging
from google.oauth2 import service_account
import os
from config import Config
from openai import OpenAI

logger = logging.getLogger(__name__)

class VideoService:
    @staticmethod
    async def analyze_video_content(video_url: str) -> Dict:
        logger.info(f"Starting video content analysis for URL: {video_url}")
        
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
            
            logger.info("Enhanced analysis complete")
            logger.info(f"Primary category: {video_analysis['content_categories']['primary_category']}")
            logger.debug(f"Analysis result: {json.dumps(video_analysis, indent=2)}")
            
            return video_analysis
                
        except Exception as e:
            logger.error(f"Error in video analysis: {str(e)}")
            logger.error(f"Error traceback: ", traceback.format_exc())
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

    async def analyze_video(self, video_data: Dict) -> Dict:
        """Analyze video content and generate metadata"""
        try:
            # Get existing analysis
            content_categories = await self._analyze_content(video_data)
            health_analysis = await self._analyze_health_impact(video_data, content_categories)
            
            # Generate a comprehensive video summary using GPT-4
            summary = await self._generate_video_summary(video_data, content_categories, health_analysis)
            
            return {
                **video_data,
                'content_categories': content_categories,
                'healthAnalysis': health_analysis,
                'videoSummary': summary,  # Add the new summary field
                'healthImpactScore': health_analysis.get('impact_score', 0)
            }
            
        except Exception as e:
            logger.error(f"Error analyzing video: {str(e)}", exc_info=True)
            raise
            
    async def _generate_video_summary(self, video_data: Dict, content_categories: Dict, health_analysis: Dict) -> str:
        """Generate a comprehensive summary of the video content"""
        try:
            # Combine all relevant information
            prompt = {
                "role": "system",
                "content": """Generate a detailed but concise summary of this video that captures:
                1. The main content and purpose
                2. Key activities or exercises shown
                3. Health and fitness aspects
                4. Target audience or skill level
                5. Notable techniques or methods demonstrated
                
                Format as a single, flowing paragraph."""
            }
            
            # Create context from available data
            context = f"""
            Video Title: {video_data.get('caption', 'Untitled')}
            
            Content Categories:
            - Primary: {content_categories.get('primary_category', '')}
            - Activities: {', '.join([a['label'] for a in content_categories.get('activities', [])])}
            - Environment: {content_categories.get('environment', '')}
            
            Health Analysis:
            - Impact: {health_analysis.get('summary', '')}
            - Benefits: {', '.join(health_analysis.get('benefits', []))}
            - Tags: {', '.join(health_analysis.get('tags', []))}
            """
            
            # Get summary from GPT-4
            client = OpenAI(api_key=Config.OPENAI_API_KEY)
            response = client.chat.completions.create(
                model="gpt-4-turbo-preview",
                messages=[
                    prompt,
                    {"role": "user", "content": context}
                ],
                temperature=0.7,
                max_tokens=200
            )
            
            return response.choices[0].message.content.strip()
            
        except Exception as e:
            logger.error(f"Error generating video summary: {str(e)}", exc_info=True)
            raise