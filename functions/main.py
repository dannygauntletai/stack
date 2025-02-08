import json
import logging
import tempfile
import os
from typing import Dict, Tuple

import firebase_admin
from firebase_admin import credentials, firestore, storage
from firebase_functions import https_fn
from google.cloud import videointelligence_v1 as videointelligence
from google.cloud import vision
from openai import OpenAI
from config import Config
from firebase_functions.options import CorsOptions

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Firebase Admin SDK at the module level
cred = credentials.Certificate("service-account.json")
_app = firebase_admin.initialize_app(cred, {
    'storageBucket': 'tiktok-18d7a.firebasestorage.app'
})
_db = firestore.client()

def _ensure_initialized():
    """Get the Firestore client."""
    global _db
    if not _db:
        _db = firestore.client()
    return _db

def _analyze_video_content(video_url: str) -> Dict:
    """Analyze video content using Google Video Intelligence API."""
    logger.info("Starting video content analysis")
    
    try:
        # Initialize video intelligence client
        video_client = videointelligence.VideoIntelligenceServiceClient()
        
        # Configure the video intelligence request
        features = [
            videointelligence.Feature.LABEL_DETECTION,
            videointelligence.Feature.OBJECT_TRACKING
        ]
        
        # Use the GCS URL directly
        request = videointelligence.AnnotateVideoRequest(
            input_uri=video_url,
            features=features
        )
        
        # Make the video intelligence request
        operation = video_client.annotate_video(request)
        logger.info("Waiting for video analysis to complete...")
        
        try:
            result = operation.result(timeout=480)  # 8 minute timeout
        except Exception as e:
            logger.error(f"Video analysis operation timed out or failed: {e}")
            raise ValueError("Video analysis failed to complete in time")
        
        video_analysis = {
            'texts': [],
            'labels': [],
            'objects': []
        }
        
        # Process video intelligence annotations
        for annotation_result in result.annotation_results:
            # Process text annotations
            if annotation_result.text_annotations:
                logger.info("Text Annotations:")
                for text in annotation_result.text_annotations:
                    detected_text = text.text
                    logger.info(f"Detected Text: {detected_text}")
                    video_analysis['texts'].append(detected_text)
            
            # Process label annotations
            if annotation_result.segment_label_annotations:
                logger.info("Label Annotations:")
                for label in annotation_result.segment_label_annotations:
                    label_info = {
                        'description': label.entity.description,
                        'confidence': label.segments[0].confidence
                    }
                    logger.info(f"Label: {label_info}")
                    video_analysis['labels'].append(label_info)
            
            # Process object annotations
            if annotation_result.object_annotations:
                logger.info("Object Annotations:")
                for obj in annotation_result.object_annotations:
                    obj_info = {
                        'name': obj.entity.description,
                        'confidence': obj.confidence
                    }
                    logger.info(f"Object: {obj_info}")
                    video_analysis['objects'].append(obj_info)
        
        # Add environment assessment based on labels
        video_analysis['environment'] = {
            'setting': _categorize_environment(video_analysis['labels']),
            'safety_assessment': {
                'violence': 'UNKNOWN',
                'medical': 'UNKNOWN',
            }
        }
        
        logger.info("=== Processed Analysis Data ===")
        logger.info(json.dumps(video_analysis, indent=2))
        
        return video_analysis
            
    except Exception as e:
        logger.error(f"Error in video analysis: {str(e)}")
        raise ValueError(f"Video analysis failed: {str(e)}")

def _categorize_environment(labels) -> str:
    """Categorize environment based on labels."""
    environment_keywords = {
        'indoor_gym': ['gym', 'fitness center', 'weight room'],
        'outdoor': ['park', 'street', 'garden', 'outdoor'],
        'home': ['living room', 'bedroom', 'home'],
        'studio': ['studio', 'dance studio', 'yoga studio']
    }
    
    # Labels are now dictionaries with 'description' key
    label_texts = [label['description'].lower() for label in labels]
    
    for env_type, keywords in environment_keywords.items():
        if any(keyword in label_texts for keyword in keywords):
            return env_type
            
    return 'unknown'

def _get_health_impact_analysis(video_analysis: Dict) -> Tuple[float, Dict]:
    """Get health impact analysis from GPT-3.5 Turbo."""
    logger.info("Getting health impact analysis")
    
    # Initialize OpenAI client inside the function
    openai_client = OpenAI()
    
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

    Respond with valid JSON in this exact format (no other text):
    {
        "score": <integer_minutes>,
        "reasoning": {
            "summary": "<one-line impact summary>",
            "content_type": "<what kind of content was detected>",
            "longevity_impact": "<detailed explanation of life expectancy calculation>",
            "benefits": ["<benefit1>", "<benefit2>", ...],
            "risks": ["<risk1>", "<risk2>", ...],
            "recommendations": ["<improvement1>", "<improvement2>", ...],
            "tags": ["<tag1>", "<tag2>", ...]
        }
    }

    For tags: Generate 2-5 relevant hashtags that describe the content and health impact (e.g. #Fitness, #MentalHealth, #Meditation).
    """
    
    try:
        response = openai_client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": f"Analyze this content: {json.dumps(video_analysis)}"}
            ],
            temperature=0.7
        )
        
        # Log the raw response
        content = response.choices[0].message.content
        logger.info(f"Raw GPT response: {content}")
        
        # Parse GPT's response
        analysis = json.loads(content)
        logger.info(f"Parsed analysis: {json.dumps(analysis, indent=2)}")
        
        return float(analysis['score']), analysis['reasoning']
        
    except Exception as e:
        logger.error(f"Error in GPT analysis: {str(e)}")
        raise

@https_fn.on_call(
    region="us-central1",
    cors=CorsOptions(
        cors_origins=["*"],
        cors_methods=["GET", "POST"]
    )
)
def analyze_health(request: https_fn.CallableRequest) -> Dict:
    """Firebase Callable Function to analyze video health impact."""
    try:
        logger.info("=== Received Request ===")
        logger.info(f"Auth context: {request.auth}")
        
        # Verify authentication
        if not request.auth:
            logger.error("No authentication context")
            raise https_fn.UnauthenticatedError("User must be authenticated")
            
        logger.info(f"Authenticated user ID: {request.auth.uid}")
        
        # Get data from the request
        data = request.data
        logger.info(f"Request data: {data}")
        
        # Get video URL from data
        video_url = data.get('videoUrl')
        if not video_url:
            raise ValueError("Missing videoUrl field")
            
        logger.info(f"Starting analysis for video at {video_url}")
        
        # Initialize on first request
        db = _ensure_initialized()
        
        # Find video document by URL
        videos_ref = db.collection('videos')
        query = videos_ref.where('videoUrl', '==', video_url).limit(1)
        docs = query.get()
        
        if not docs:
            raise ValueError(f"No video document found with URL: {video_url}")
            
        video_doc = docs[0]
        video_id = video_doc.id
        
        logger.info(f"Found video document with ID: {video_id}")
        
        # Update status to processing
        video_doc.reference.update({'analysisStatus': 'processing'})
        
        # Add timeout handling for the entire operation
        try:
            video_analysis = _analyze_video_content(video_url)
        except Exception as e:
            logger.error(f"Video analysis failed: {str(e)}")
            return {
                'success': False,
                'error': str(e),
                'details': {
                    'stage': 'video_analysis',
                    'message': str(e)
                }
            }
            
        # Get health impact analysis
        score, reasoning = _get_health_impact_analysis(video_analysis)
        
        # Update Firestore with tags included
        video_doc.reference.update({
            'healthImpactScore': score,
            'healthAnalysis': reasoning,
            'analysisStatus': 'completed',
            'tags': reasoning.get('tags', [])  # Add tags to the document
        })
        
        logger.info(f"Analysis complete for video {video_id}")
        
        return {
            'success': True,
            'score': score,
            'reasoning': reasoning,
            'videoId': video_id
        }
        
    except Exception as e:
        logger.error(f"Error: {str(e)}")
        return {
            'success': False,
            'error': str(e)
        }

@https_fn.on_request()
def analyze_health_status(req: https_fn.Request) -> https_fn.Response:
    """HTTP Cloud Function to check health analysis service status."""
    try:
        # Simple test query to verify Firestore connection
        db = _ensure_initialized()
        db.collection('videos').limit(1).get()
        
        return https_fn.Response(
            json.dumps({
                'status': 'healthy',
                'database': 'connected',
                'service': 'video_health_analysis'
            }),
            content_type='application/json'
        )
    except Exception as e:
        return https_fn.Response(
            json.dumps({
                'status': 'unhealthy',
                'error': str(e),
                'service': 'video_health_analysis'
            }),
            status=500,
            content_type='application/json'
        ) 