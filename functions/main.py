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

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Firebase Admin SDK only when needed
_app = None
_db = None

def _ensure_initialized():
    global _app, _db
    if not _app:
        cred = credentials.Certificate(Config.GOOGLE_APPLICATION_CREDENTIALS)
        _app = firebase_admin.initialize_app(cred, {
            'storageBucket': Config.FIREBASE_STORAGE_BUCKET
        })
        _db = firestore.client()
    return _db

def _analyze_video_content(video_url: str) -> Dict:
    """Analyze video content using Google Video Intelligence and Vision API."""
    logger.info("Starting video content analysis")
    
    # Initialize clients inside the function
    bucket = storage.bucket(Config.FIREBASE_STORAGE_BUCKET)
    video_client = videointelligence.VideoIntelligenceServiceClient()
    vision_client = vision.ImageAnnotatorClient()
    
    # Get video from Storage - modify URL parsing
    try:
        # Remove gs:// and split bucket/path
        path = video_url.replace('gs://', '')
        if '/' in path:
            blob_path = path.split('/', 1)[1]  # Get everything after first /
        else:
            raise ValueError(f"Invalid storage URL format: {video_url}")
            
        logger.info(f"Attempting to download blob: {blob_path}")
        blob = bucket.blob(blob_path)
        
        with tempfile.NamedTemporaryFile(suffix='.mp4', delete=False) as temp_video:
            try:
                # Download video to temp file
                blob.download_to_filename(temp_video.name)
                
                # Read video content
                with open(temp_video.name, 'rb') as video_file:
                    video_content = video_file.read()
                
                # Configure the video intelligence request
                features = [
                    videointelligence.Feature.LABEL_DETECTION,
                    videointelligence.Feature.TEXT_DETECTION,
                    videointelligence.Feature.OBJECT_TRACKING
                ]
                
                request = videointelligence.AnnotateVideoRequest(
                    input_content=video_content,
                    features=features
                )
                
                # Make the video intelligence request
                operation = video_client.annotate_video(request)
                logger.info("Waiting for video analysis to complete...")
                result = operation.result()
                
                # Process results
                detected_items = {
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
                
                # Vision API analysis on middle frame
                import cv2
                cap = cv2.VideoCapture(temp_video.name)
                frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
                cap.set(cv2.CAP_PROP_POS_FRAMES, frame_count // 2)
                success, frame = cap.read()
                cap.release()
                
                if success:
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
                    
                    # Add Vision API results
                    detected_items['environment'] = {
                        'setting': _categorize_environment(response.label_annotations),
                        'objects': [obj.name for obj in response.localized_object_annotations],
                        'safety_assessment': {
                            'violence': response.safe_search_annotation.violence.name,
                            'medical': response.safe_search_annotation.medical.name,
                        }
                    }
                
                logger.info("=== Processed Analysis Data ===")
                logger.info(json.dumps(detected_items, indent=2))
                
                return detected_items
            finally:
                # Clean up temp file
                if os.path.exists(temp_video.name):
                    os.unlink(temp_video.name)
    except Exception as e:
        logger.error(f"Error downloading video: {str(e)}")
        raise

def _categorize_environment(labels) -> str:
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

def _get_health_impact_analysis(video_analysis: Dict) -> Tuple[float, Dict]:
    """Get health impact analysis from GPT-4."""
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
            "recommendations": ["<improvement1>", "<improvement2>", ...]
        }
    }
    """
    
    try:
        response = openai_client.chat.completions.create(
            model="gpt-4",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": f"Analyze this content: {json.dumps(video_analysis)}"}
            ]
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

@https_fn.on_request()
def analyze_health(req: https_fn.Request) -> https_fn.Response:
    """HTTP Cloud Function to analyze video health impact."""
    try:
        # Initialize on first request
        db = _ensure_initialized()
        
        # Get request data
        data = req.get_json()
        
        if not data:
            return https_fn.Response("No JSON data provided", status=400)
            
        video_url = data.get('videoUrl')
        
        if not video_url:
            return https_fn.Response("Missing videoUrl field", status=400)
            
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
        
        # Update status to processing
        video_doc.reference.update({'analysisStatus': 'processing'})
        
        # Analyze video content
        video_analysis = _analyze_video_content(video_url)
        
        # Get health impact analysis
        score, reasoning = _get_health_impact_analysis(video_analysis)
        
        # Update Firestore
        video_doc.reference.update({
            'healthImpactScore': score,
            'healthAnalysis': reasoning,
            'analysisStatus': 'completed'
        })
        
        logger.info(f"Analysis complete for video {video_id}")
        
        return https_fn.Response(
            json.dumps({
                'success': True,
                'score': score,
                'reasoning': reasoning,
                'videoId': video_id
            }),
            content_type='application/json'
        )
        
    except Exception as e:
        logger.error(f"Error analyzing video: {str(e)}", exc_info=True)
        
        # Update status to failed if we have a video document
        if 'video_doc' in locals():
            video_doc.reference.update({'analysisStatus': 'failed'})
        
        return https_fn.Response(
            json.dumps({
                'success': False,
                'error': str(e)
            }),
            status=500,
            content_type='application/json'
        )

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