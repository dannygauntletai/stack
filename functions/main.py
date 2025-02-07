import asyncio
import json
import logging
import os
import tempfile
from typing import Dict, List, Tuple

import cv2
import firebase_admin
import mediapipe as mp
import numpy as np
from firebase_admin import credentials, firestore, storage
from google.cloud import videointelligence_v1 as videointelligence
from google.cloud import vision
from openai import OpenAI

from config import Config

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Firebase with service account
cred = credentials.Certificate(Config.GOOGLE_APPLICATION_CREDENTIALS)
firebase_admin.initialize_app(cred, {
    'storageBucket': Config.FIREBASE_STORAGE_BUCKET
})

# Initialize services
db = firestore.client()
storage_client = storage.bucket()
openai_client = OpenAI(api_key=Config.OPENAI_API_KEY)
video_client = videointelligence.VideoIntelligenceServiceClient()
vision_client = vision.ImageAnnotatorClient()

class VideoAnalyzer:
    """Class to handle video analysis pipeline."""
    
    def __init__(self, video_url: str):
        self.video_url = video_url
        self.temp_file_path = None
        
    async def analyze(self) -> Tuple[float, Dict]:
        """Analyze video and return health impact score with reasoning."""
        try:
            self.temp_file_path = await self._download_video()
            logger.info(f"Video downloaded to {self.temp_file_path}")
            
            # Run parallel analysis
            tasks = await asyncio.gather(
                self._analyze_with_video_intelligence(),
                self._analyze_pose(),
                self._analyze_environment()
            )
            
            video_analysis, objects = tasks[0]  # This is now a tuple of (detected_items, objects)
            pose_data = tasks[1]
            environment_data = tasks[2]
            
            # Get additional context for detected items
            detected_items = {
                'texts': video_analysis['texts'],
                'labels': video_analysis['labels'],
                'objects': objects
            }
            content_context = await self._get_content_context(detected_items)
            
            # Combine all analysis data
            analysis_data = {
                'video_length': self._get_video_duration(),
                'detected_content': detected_items,
                'content_context': content_context,
                'pose_analysis': pose_data,
                'environment': environment_data
            }
            
            logger.info(f"Complete analysis data: {json.dumps(analysis_data, indent=2)}")
            
            # Get GPT analysis
            score, reasoning = await self._get_gpt_analysis(analysis_data)
            return score, reasoning
            
        finally:
            if self.temp_file_path and os.path.exists(self.temp_file_path):
                os.unlink(self.temp_file_path)
                logger.info("Cleaned up temporary file")

    async def _analyze_with_video_intelligence(self) -> Tuple[Dict, List[Dict]]:
        """Analyze video using Google Video Intelligence API."""
        logger.info("Starting Video Intelligence analysis")
        
        with open(self.temp_file_path, 'rb') as file:
            input_content = file.read()
        
        features = [
            videointelligence.Feature.LABEL_DETECTION,
            videointelligence.Feature.TEXT_DETECTION,
            videointelligence.Feature.OBJECT_TRACKING
        ]
        
        request = videointelligence.AnnotateVideoRequest(
            input_content=input_content,
            features=features
        )
        
        operation = video_client.annotate_video(request)
        logger.info("Waiting for Video Intelligence analysis to complete...")
        result = await asyncio.to_thread(operation.result)
        
        # Debug raw results
        logger.info("=== Raw Video Intelligence Results ===")
        detected_items = {
            'texts': [],
            'labels': [],
            'objects': []
        }
        
        for annotation_result in result.annotation_results:
            # Process text annotations
            if annotation_result.text_annotations:
                logger.info("Text Annotations:")
                for text in annotation_result.text_annotations:
                    detected_text = text.text
                    logger.info(f"Detected Text: {detected_text}")
                    detected_items['texts'].append(detected_text)
            
            # Process label annotations
            if annotation_result.segment_label_annotations:
                logger.info("Label Annotations:")
                for label in annotation_result.segment_label_annotations:
                    label_info = {
                        'description': label.entity.description,
                        'confidence': label.segments[0].confidence
                    }
                    logger.info(f"Label: {label_info}")
                    detected_items['labels'].append(label_info)
            
            # Process object annotations
            if annotation_result.object_annotations:
                logger.info("Object Annotations:")
                for obj in annotation_result.object_annotations:
                    obj_info = {
                        'name': obj.entity.description,
                        'confidence': obj.confidence
                    }
                    logger.info(f"Object: {obj_info}")
                    detected_items['objects'].append(obj_info)
        
        logger.info("=== Processed Analysis Data ===")
        logger.info(json.dumps(detected_items, indent=2))
        
        return detected_items, detected_items['objects']

    async def _analyze_pose(self) -> Dict:
        """Analyze pose and movement using MediaPipe."""
        logger.info("Starting pose analysis")
        
        cap = cv2.VideoCapture(self.temp_file_path)
        frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        fps = int(cap.get(cv2.CAP_PROP_FPS))
        
        with mp.solutions.pose.Pose(
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5
        ) as pose:
            pose_data = []
            frame_idx = 0
            
            while cap.isOpened():
                success, frame = cap.read()
                if not success:
                    break
                
                # Process every 5th frame for efficiency
                if frame_idx % 5 == 0:
                    results = pose.process(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
                    if results.pose_landmarks:
                        pose_data.append(self._extract_pose_metrics(results.pose_landmarks))
                
                frame_idx += 1
            
        cap.release()
        
        return self._analyze_movement_quality(pose_data)

    async def _analyze_environment(self) -> Dict:
        """Analyze environment using Vision API."""
        logger.info("Starting environment analysis")
        
        cap = cv2.VideoCapture(self.temp_file_path)
        frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        
        # Analyze middle frame for environment
        cap.set(cv2.CAP_PROP_POS_FRAMES, frame_count // 2)
        success, frame = cap.read()
        cap.release()
        
        if not success:
            return {}
        
        # Convert frame to Vision API format
        success, buffer = cv2.imencode('.jpg', frame)
        content = buffer.tobytes()
        
        # Analyze with Vision API
        image = vision.Image(content=content)
        response = vision_client.annotate_image({
            'image': image,
            'features': [
                {'type_': vision.Feature.Type.OBJECT_LOCALIZATION},
                {'type_': vision.Feature.Type.LABEL_DETECTION},
                {'type_': vision.Feature.Type.SAFE_SEARCH_DETECTION},
            ]
        })
        
        return {
            'setting': self._categorize_environment(response.label_annotations),
            'objects': [obj.name for obj in response.localized_object_annotations],
            'safety_assessment': {
                'violence': response.safe_search_annotation.violence.name,
                'medical': response.safe_search_annotation.medical.name,
            }
        }

    def _extract_pose_metrics(self, landmarks) -> Dict:
        """Extract metrics from pose landmarks."""
        # Calculate various metrics from landmarks
        return {
            'balance': self._calculate_balance(landmarks),
            'range_of_motion': self._calculate_rom(landmarks),
            'symmetry': self._calculate_symmetry(landmarks),
            'stability': self._calculate_stability(landmarks)
        }

    def _analyze_movement_quality(self, pose_data: List[Dict]) -> Dict:
        """Analyze overall movement quality from pose data."""
        if not pose_data:
            return {}
            
        return {
            'balance_score': sum(d['balance'] for d in pose_data) / len(pose_data),
            'rom_score': sum(d['range_of_motion'] for d in pose_data) / len(pose_data),
            'symmetry_score': sum(d['symmetry'] for d in pose_data) / len(pose_data),
            'stability_score': sum(d['stability'] for d in pose_data) / len(pose_data)
        }

    # Helper methods for calculations
    def _calculate_balance(self, landmarks) -> float:
        # Implement balance calculation
        return 0.8  # Placeholder

    def _calculate_rom(self, landmarks) -> float:
        # Implement range of motion calculation
        return 0.7  # Placeholder

    def _calculate_symmetry(self, landmarks) -> float:
        # Implement symmetry calculation
        return 0.9  # Placeholder

    def _calculate_stability(self, landmarks) -> float:
        # Implement stability calculation
        return 0.85  # Placeholder

    def _categorize_environment(self, labels) -> str:
        """Categorize environment based on Vision API labels."""
        environment_keywords = {
            'indoor_gym': ['gym', 'fitness center', 'weight room'],
            'outdoor': ['park', 'street', 'garden', 'outdoor'],
            'home': ['living room', 'bedroom', 'home'],
            'studio': ['studio', 'dance studio', 'yoga studio']
        }
        
        label_texts = [label.description.lower() for label in labels]
        
        for env_type, keywords in environment_keywords.items():
            if any(keyword in label_texts for keyword in keywords):
                return env_type
                
        return 'unknown'

    def _get_video_duration(self) -> float:
        """Get video duration in seconds."""
        cap = cv2.VideoCapture(self.temp_file_path)
        fps = cap.get(cv2.CAP_PROP_FPS)
        frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        cap.release()
        return frame_count / fps

    async def _download_video(self) -> str:
        """Download video from Firebase Storage to temp file."""
        with tempfile.NamedTemporaryFile(suffix='.mp4', delete=False) as temp_file:
            # Remove 'gs://bucket-name/' prefix
            blob_path = self.video_url.replace(f'gs://{Config.FIREBASE_STORAGE_BUCKET}/', '')
            blob = storage_client.blob(blob_path)
            blob.download_to_filename(temp_file.name)
            return temp_file.name
    
    async def _get_content_context(self, detected_items: Dict) -> Dict:
        """Enrich detected items with additional context."""
        logger.info("Getting additional context for detected items...")
        
        context = {}
        
        # Combine all detected items for analysis
        all_items = {
            'text': detected_items.get('texts', []),
            'labels': [label['description'] for label in detected_items.get('labels', [])],
            'objects': [obj['name'] for obj in detected_items.get('objects', [])]
        }
        
        context_prompt = """Analyze the detected items in this video and provide health/longevity context.
        Consider all possible categories:

        1. Physical Activity/Exercise:
           - Type of exercise/movement
           - Intensity level
           - Potential health benefits/risks

        2. Food/Nutrition:
           - Type of food/drink
           - Nutritional value
           - Health implications

        3. Mental/Educational:
           - Books, learning materials
           - Mental stimulation type
           - Cognitive benefits

        4. Lifestyle/Habits:
           - Sleep-related items
           - Stress management
           - Social interaction

        5. Environment:
           - Setting (gym, home, outdoors)
           - Safety considerations
           - Air quality/lighting

        6. Medical/Health:
           - Health-related items
           - Medical equipment
           - Wellness products

        Respond in JSON format:
        {
            "primary_category": "<main category from above>",
            "detected_items": {
                "main_focus": "<primary item/activity>",
                "related_items": ["<item1>", "<item2>"]
            },
            "health_context": {
                "description": "<detailed health/longevity context>",
                "typical_usage": "<how this is typically used/done>",
                "frequency": "<typical frequency of use/practice>",
                "scientific_backing": "<brief mention of relevant health studies if applicable>"
            },
            "additional_info": {
                "benefits": ["<benefit1>", "<benefit2>"],
                "considerations": ["<consideration1>", "<consideration2>"]
            }
        }
        """

        try:
            response = openai_client.chat.completions.create(
                model="gpt-4",
                messages=[
                    {"role": "system", "content": context_prompt},
                    {"role": "user", "content": f"Analyze these detected items: {json.dumps(all_items, indent=2)}"}
                ]
            )
            
            content_context = json.loads(response.choices[0].message.content)
            logger.info(f"Got content context: {json.dumps(content_context, indent=2)}")
            context['content_context'] = content_context
            
        except Exception as e:
            logger.error(f"Error getting content context: {str(e)}")
            context['content_context'] = {"error": str(e)}
        
        return context

    async def _get_gpt_analysis(self, analysis_data: Dict) -> Tuple[float, Dict]:
        """Get health impact analysis from GPT."""
        try:
            logger.info(f"Sending analysis data to GPT: {json.dumps(analysis_data, indent=2)}")
            
            system_prompt = """You are a longevity impact analyzer for short-form videos (typically 15 seconds). 
            Your task is to analyze the content shown and calculate its LIFETIME impact on life expectancy if this became a regular part of someone's lifestyle.

            Important Calculation Context:
            - Calculate the TOTAL MINUTES added/subtracted over a lifetime (30+ years) of regular engagement
            - Consider cumulative effects (both positive and negative)
            - Factor in compound benefits/risks over time
            - Account for age-related variations in impact
            - Consider habit formation and sustainability

            Example Lifetime Impact Calculations:
            - Daily junk food consumption: -2000 to -5000 minutes (4-10 years reduced lifespan)
            - Regular exercise routine: +2000 to +4000 minutes (4-8 years added lifespan)
            - Reading/learning habit: +1000 to +2000 minutes (2-4 years added lifespan due to cognitive benefits)
            - Harmful habits: -3000 to -6000 minutes (6-12 years reduced lifespan)

            The video analysis data includes:
            - Detected text with context (book descriptions, brand information)
            - Object and scene labels
            - Movement/pose analysis (if people are present)
            - Environmental context

            Pay special attention to the content_context which provides deeper understanding of detected items.
            For books or educational content:
            - Consider the subject matter's impact on mental health
            - Factor in cognitive benefits of regular reading/learning
            - Consider stress reduction or intellectual stimulation
            
            Consider different types of content:
            1. Physical Activities:
               - Exercise benefits
               - Movement quality
               - Safety considerations
            
            2. Food/Drink:
               - Nutritional value
               - Health impact
               - Consumption patterns
            
            3. Educational/Mental:
               - Learning and cognitive benefits (books, reading, educational content)
               - Mental stimulation
               - Stress reduction/increase
            
            4. Lifestyle/Habits:
               - Daily routines
               - Social interaction
               - Environmental factors

            Calculate a score in TOTAL LIFETIME MINUTES that this activity/content would add to (+) or subtract from (-) life expectancy.
            Consider these lifetime impact ranges:
            - Severely harmful habits/activities: -3000 to -6000 minutes
            - Moderately harmful: -1000 to -3000 minutes
            - Slightly negative: -100 to -1000 minutes
            - Neutral: -100 to +100 minutes
            - Slightly beneficial: +100 to +1000 minutes
            - Moderately beneficial: +1000 to +3000 minutes
            - Highly beneficial: +3000 to +6000 minutes

            For example:
            - Regular reading/learning: +1500 minutes (cognitive benefits compound over decades)
            - Daily processed food consumption: -2500 minutes (cumulative health impact over years)
            - Consistent exercise routine: +3000 minutes (lifetime of physical benefits)
            - Poor sleep habits: -2000 minutes (long-term health deterioration)

            Respond with valid JSON in this exact format (no other text):
            {
                "score": <integer_minutes>,
                "reasoning": {
                    "summary": "<one-line impact summary>",
                    "content_type": "<what kind of content was detected>",
                    "longevity_impact": "<detailed explanation of life expectancy calculation>",
                    "benefits": ["<benefit1>", "<benefit2>", ...],
                    "risks": ["<risk1>", "<risk2>", ...],
                    "recommendations": ["<improvement1>", "<improvement2>", ...]
                }
            }
            """
            
            response = openai_client.chat.completions.create(
                model="gpt-4",
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": f"Analyze this video data: {json.dumps(analysis_data)}"}
                ]
            )
            
            # Log the raw response
            content = response.choices[0].message.content
            logger.info(f"Raw GPT response: {content}")
            
            # Parse GPT's response
            analysis = json.loads(content)
            logger.info(f"Parsed analysis: {json.dumps(analysis, indent=2)}")
            
            score = float(analysis['score'])
            reasoning = analysis['reasoning']
            
            return score, reasoning
            
        except json.JSONDecodeError as e:
            logger.error(f"JSON Parse error: {str(e)}")
            logger.error(f"Failed content: {content}")
            return 0.0, {"error": "Failed to parse analysis"}
        except KeyError as e:
            logger.error(f"Missing key in response: {str(e)}")
            logger.error(f"Response structure: {analysis}")
            return 0.0, {"error": "Invalid response structure"}
        except Exception as e:
            logger.error(f"Unexpected error in GPT analysis: {str(e)}")
            return 0.0, {"error": f"Analysis failed: {str(e)}"}

async def analyze_video_health(request) -> Dict:
    """Cloud Function entry point."""
    try:
        # Get request data
        data = request.json
        video_url = data['videoUrl']
        
        logger.info(f"Starting analysis for video at {video_url}")
        
        # Find video document by URL
        videos_ref = db.collection('videos')
        query = videos_ref.where('videoUrl', '==', video_url).limit(1)
        docs = query.get()
        
        if not docs:
            raise ValueError(f"No video document found with URL: {video_url}")
            
        video_doc = docs[0]
        video_id = video_doc.id
        
        logger.info(f"Found video document with ID: {video_id}")
        
        # Create analyzer and run analysis
        analyzer = VideoAnalyzer(video_url)
        score, reasoning = await analyzer.analyze()
        
        # Update Firestore
        video_doc.reference.update({
            'healthImpactScore': score,
            'healthAnalysis': reasoning
        })
        
        logger.info(f"Analysis complete for video {video_id}")
        
        return {
            'success': True,
            'score': score,
            'reasoning': reasoning,
            'videoId': video_id
        }
        
    except Exception as e:
        logger.error(f"Error analyzing video: {str(e)}", exc_info=True)
        return {
            'success': False,
            'error': str(e)
        } 