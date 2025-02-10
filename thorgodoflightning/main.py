from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
import firebase_admin
from firebase_admin import credentials, firestore, auth
import logging
from typing import Dict, Tuple
import json
from config import Config
from google.cloud import videointelligence_v1 as videointelligence
from openai import OpenAI
import traceback
import os

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="TikTok Health Analysis API")

# Set environment variable for credentials
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "service-account.json"

# First, ensure we're not using any emulator
if "FIRESTORE_EMULATOR_HOST" in os.environ:
    del os.environ["FIRESTORE_EMULATOR_HOST"]

# Initialize Firebase Admin SDK
try:
    print("<THOR_DEBUG> Initializing Firebase Admin...")
    print("<THOR_DEBUG> Service account path:", os.environ.get("GOOGLE_APPLICATION_CREDENTIALS"))
    
    # Initialize with explicit endpoint to production
    cred = credentials.Certificate("service-account.json")
    firebase_app = firebase_admin.initialize_app(cred)
    
    # Get Firestore client
    db = firestore.client()
    
    print("<THOR_DEBUG> Firebase Admin initialized with:")
    print(f"<THOR_DEBUG> - Project ID: {firebase_app.project_id}")
    print(f"<THOR_DEBUG> - Service Account: {cred.project_id}")
    
    # Test basic Firestore operation without collections() call
    print("<THOR_DEBUG> Testing basic Firestore operation...")
    try:
        # Try a simple document read instead
        doc_ref = db.collection('videos').document('test')
        doc = doc_ref.get(timeout=30)  # Add timeout
        print("<THOR_DEBUG> Successfully connected to Firestore")
    except Exception as e:
        print("<THOR_DEBUG> Failed to connect to Firestore:", str(e))
        raise
        
except Exception as e:
    print("<THOR_DEBUG> ERROR: Failed to initialize Firebase/Firestore")
    print(f"<THOR_DEBUG> Error type: {type(e)}")
    print(f"<THOR_DEBUG> Error message: {str(e)}")
    print(f"<THOR_DEBUG> Traceback: {traceback.format_exc()}")
    raise

print("<THOR_DEBUG> Firebase Admin initialized with project:", firebase_app.project_id)
print("<THOR_DEBUG> Using credentials for:", cred.project_id)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.post("/analyze_health")
async def analyze_health(request: Request) -> Dict:
    print("<THOR_DEBUG> Starting analyze_health endpoint")
    try:
        print("<THOR_DEBUG> === Received Request ===")
        
        # Get authorization header
        auth_header = request.headers.get('Authorization')
        print(f"<THOR_DEBUG> Auth header: {auth_header}")
        
        if auth_header and auth_header.startswith('Bearer '):
            token = auth_header.split(' ')[1]
            print("<THOR_DEBUG> Got token from header")
            try:
                decoded_token = auth.verify_id_token(token)
                print(f"<THOR_DEBUG> Decoded token: {decoded_token}")
            except Exception as e:
                print(f"<THOR_DEBUG> Token verification failed: {e}")
                raise HTTPException(status_code=401, detail="Invalid token")
        else:
            print("<THOR_DEBUG> No valid auth header found")
            raise HTTPException(status_code=401, detail="No valid authorization header")
        
        # Get raw JSON data
        body = await request.json()
        print(f"<THOR_DEBUG> Raw request body: {body}")
        
        video_url = body.get("videoUrl")
        print(f"<THOR_DEBUG> Extracted video URL: {video_url}")
        
        if not video_url:
            print("<THOR_DEBUG> ERROR: Missing videoUrl in request")
            raise HTTPException(status_code=400, detail="Missing videoUrl in request")
            
        print(f"<THOR_DEBUG> Starting analysis for video at {video_url}")
        
        # Database debug - use the global db instance
        print("<THOR_DEBUG> ====== DATABASE DEBUG ======")
        collections = db.collections()
        print("<THOR_DEBUG> Available collections:")
        for collection in collections:
            print(f"<THOR_DEBUG> - {collection.id}")
        
        print("<THOR_DEBUG> ====== USER VIDEOS DEBUG ======")
        user_videos = db.collection('videos').where('userId', '==', decoded_token['uid']).get()
        user_videos_list = list(user_videos)
        print(f"<THOR_DEBUG> Found {len(user_videos_list)} videos for user")

        for doc in user_videos_list:
            data = doc.to_dict()
            print(f"\n<THOR_DEBUG> Video Document:")
            print(f"<THOR_DEBUG> - ID: {doc.id}")
            print(f"<THOR_DEBUG> - videoUrl: {data.get('videoUrl', 'NO_URL')}")
            print(f"<THOR_DEBUG> - userId: {data.get('userId', 'NO_USER')}")
            print(f"<THOR_DEBUG> - caption: {data.get('caption', 'NO_CAPTION')}")
            print(f"<THOR_DEBUG> - createdAt: {data.get('createdAt', 'NO_DATE')}")
        
        # Now try the actual query with the exact field name
        print("\n<THOR_DEBUG> ====== VIDEO QUERY DEBUG ======")
        print(f"<THOR_DEBUG> Querying for video with URL: {video_url}")
        query = db.collection('videos').where(filter=firestore.FieldFilter('videoUrl', '==', video_url))
        docs = query.get()
        docs_list = list(docs)
        print(f"<THOR_DEBUG> Query returned {len(docs_list)} documents")
        
        if not docs_list:
            print(f"<THOR_DEBUG> ERROR: Video not found")
            raise HTTPException(
                status_code=404,
                detail=f"No video document found with URL: {video_url}"
            )
            
        video_doc = docs_list[0]
        video_id = video_doc.id
        video_data = _serialize_firestore_doc(video_doc.to_dict())
        
        print(f"<THOR_DEBUG> Found video:")
        print(f"<THOR_DEBUG> - ID: {video_id}")
        print(f"<THOR_DEBUG> - User: {video_data.get('userId')}")
        print(f"<THOR_DEBUG> - Status: {video_data.get('analysisStatus', 'new')}")
        print(f"<THOR_DEBUG> - Created: {video_data.get('createdAt')}")
        
        # Verify document belongs to requesting user
        if video_data.get('userId') != decoded_token['uid']:
            print(f"<THOR_DEBUG> ERROR: Video belongs to user {video_data.get('userId')}, but request is from {decoded_token['uid']}")
            raise HTTPException(
                status_code=403,
                detail="You don't have permission to analyze this video"
            )

        # Update status to processing
        print("<THOR_DEBUG> Updating video status to 'processing'")
        video_doc.reference.update({'analysisStatus': 'processing'})
        
        # Analyze video content
        print("<THOR_DEBUG> Starting video content analysis")
        video_analysis = _analyze_video_content(video_url)
        print(f"<THOR_DEBUG> Video analysis complete: {json.dumps(video_analysis, indent=2)}")
        
        # Get health impact analysis
        print("<THOR_DEBUG> Starting health impact analysis")
        score, reasoning = _get_health_impact_analysis(video_analysis)
        print(f"<THOR_DEBUG> Health analysis complete - Score: {score}")
        print(f"<THOR_DEBUG> Reasoning: {json.dumps(reasoning, indent=2)}")
        
        # Update Firestore
        print("<THOR_DEBUG> Updating Firestore with analysis results")
        video_doc.reference.update({
            'healthImpactScore': score,
            'healthAnalysis': reasoning,
            'analysisStatus': 'completed'
        })
        
        print(f"<THOR_DEBUG> Analysis complete for video {video_id}")
        
        return {
            'success': True,
            'score': score,
            'reasoning': reasoning,
            'videoId': video_id
        }
        
    except Exception as e:
        print(f"<THOR_DEBUG> ERROR in analyze_health: {str(e)}")
        print(f"<THOR_DEBUG> Error type: {type(e)}")
        print(f"<THOR_DEBUG> Error traceback: ", traceback.format_exc())
        raise HTTPException(
            status_code=500,
            detail=str(e)
        )

@app.get("/health")
async def health_check():
    """Check service health status."""
    try:
        # Test Firestore connection
        db.collection('videos').limit(1).get()
        
        return {
            'status': 'healthy',
            'database': 'connected',
            'service': 'video_health_analysis'
        }
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=str(e)
        )

def _analyze_video_content(video_url: str) -> Dict:
    print("<THOR_DEBUG> Starting _analyze_video_content")
    print(f"<THOR_DEBUG> Processing video URL: {video_url}")
    
    try:
        print("<THOR_DEBUG> Initializing video intelligence client")
        video_client = videointelligence.VideoIntelligenceServiceClient()
        
        # Firebase Storage URL format: gs://bucket-name/path/to/video.mp4
        if not video_url.startswith('gs://'):
            print("<THOR_DEBUG> ERROR: Invalid video URL format. Expected gs:// URL")
            raise ValueError("Invalid video URL format. Expected gs:// URL")
            
        print("<THOR_DEBUG> Configuring video analysis features")
        features = [
            videointelligence.Feature.LABEL_DETECTION,
            videointelligence.Feature.OBJECT_TRACKING,
            videointelligence.Feature.EXPLICIT_CONTENT_DETECTION  # Add safety check
        ]
        
        print("<THOR_DEBUG> Creating video analysis request")
        request = videointelligence.AnnotateVideoRequest(
            input_uri=video_url,  # Direct GCS path from Firebase Storage
            features=features
        )
        
        print("<THOR_DEBUG> Submitting video analysis request")
        operation = video_client.annotate_video(request)
        print("<THOR_DEBUG> Waiting for video analysis to complete...")
        
        try:
            result = operation.result(timeout=480)  # 8 minute timeout
            print("<THOR_DEBUG> Video analysis operation completed successfully")
        except Exception as e:
            print(f"<THOR_DEBUG> ERROR: Video analysis operation failed: {e}")
            raise ValueError("Video analysis failed to complete in time")
        
        video_analysis = {
            'texts': [],
            'labels': [],
            'objects': [],
            'safety_annotations': []
        }
        
        # Process video intelligence annotations
        for annotation_result in result.annotation_results:
            # Process label annotations
            if annotation_result.segment_label_annotations:
                for label in annotation_result.segment_label_annotations:
                    label_info = {
                        'description': label.entity.description,
                        'confidence': label.segments[0].confidence
                    }
                    video_analysis['labels'].append(label_info)
            
            # Process object annotations
            if annotation_result.object_annotations:
                for obj in annotation_result.object_annotations:
                    obj_info = {
                        'name': obj.entity.description,
                        'confidence': obj.confidence,
                        'time_offset': {
                            'start': obj.segment.start_time_offset.total_seconds(),
                            'end': obj.segment.end_time_offset.total_seconds()
                        }
                    }
                    video_analysis['objects'].append(obj_info)
                    
            # Process safety annotations
            if annotation_result.explicit_annotation:
                frames = annotation_result.explicit_annotation.frames
                for frame in frames:
                    safety_info = {
                        'time_offset': frame.time_offset.total_seconds(),
                        # The API only provides adult content detection
                        'adult_content': frame.pornography_likelihood.name
                    }
                    video_analysis['safety_annotations'].append(safety_info)
        
        # Add environment assessment
        video_analysis['environment'] = {
            'setting': _categorize_environment(video_analysis['labels']),
            'safety_assessment': _assess_safety(video_analysis['safety_annotations'])
        }
        
        print("<THOR_DEBUG> === Processed Analysis Data ===")
        print("<THOR_DEBUG> Analysis data: ", json.dumps(video_analysis, indent=2))
        
        return video_analysis
            
    except Exception as e:
        print(f"<THOR_DEBUG> ERROR in video analysis: {str(e)}")
        print(f"<THOR_DEBUG> Error traceback: ", traceback.format_exc())
        raise ValueError(f"Video analysis failed: {str(e)}")

def _categorize_environment(labels) -> str:
    """Categorize environment based on labels."""
    environment_keywords = {
        'indoor_gym': ['gym', 'fitness center', 'weight room'],
        'outdoor': ['park', 'street', 'garden', 'outdoor'],
        'home': ['living room', 'bedroom', 'home'],
        'studio': ['studio', 'dance studio', 'yoga studio']
    }
    
    label_texts = [label['description'].lower() for label in labels]
    
    for env_type, keywords in environment_keywords.items():
        if any(keyword in label_texts for keyword in keywords):
            return env_type
            
    return 'unknown'

def _clean_tags(tags: list, score: float = 0) -> list:
    """Clean and format tags."""
    cleaned = []
    for tag in tags:
        tag = tag.replace('#', '').strip()
        single_word = tag.split()[0]
        clean_word = ''.join(c for c in single_word if c.isalnum())
        if clean_word:
            cleaned.append(clean_word.lower())
    return list(set(cleaned))

def _get_health_impact_analysis(video_analysis: Dict) -> Tuple[float, Dict]:
    print("<THOR_DEBUG> Starting health impact analysis")
    print(f"<THOR_DEBUG> Input analysis: {json.dumps(video_analysis, indent=2)}")
    
    try:
        print("<THOR_DEBUG> Initializing OpenAI client")
        openai_client = OpenAI()
        
        print("<THOR_DEBUG> Sending request to GPT")
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
                "tags": ["<tag1>", "<tag2>", "<tag3>"]
            }
        }
        """
        
        response = openai_client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": f"Analyze this content: {json.dumps(video_analysis)}"}
            ],
            temperature=0.7
        )
        
        content = response.choices[0].message.content
        print(f"<THOR_DEBUG> Raw GPT response: {content}")
        
        analysis = json.loads(content)
        score = float(analysis['score'])
        print(f"<THOR_DEBUG> Parsed score: {score}")
        
        if 'reasoning' in analysis and 'tags' in analysis['reasoning']:
            print("<THOR_DEBUG> Cleaning tags")
            analysis['reasoning']['tags'] = _clean_tags(analysis['reasoning']['tags'], score)
            print(f"<THOR_DEBUG> Cleaned tags: {analysis['reasoning']['tags']}")
        
        print("<THOR_DEBUG> === Parsed Analysis ===")
        print("<THOR_DEBUG> Parsed analysis: ", json.dumps(analysis, indent=2))
        
        return score, analysis['reasoning']
        
    except Exception as e:
        print(f"<THOR_DEBUG> ERROR in health impact analysis: {str(e)}")
        print(f"<THOR_DEBUG> Error traceback: ", traceback.format_exc())
        raise 

def _assess_safety(safety_annotations: list) -> dict:
    """Assess overall safety of the video content."""
    if not safety_annotations:
        return {
            'adult_content': 'UNKNOWN'
        }
        
    # Get all adult content likelihood levels
    adult_levels = [frame['adult_content'] for frame in safety_annotations]
    
    # Return the most severe level found
    return {
        'adult_content': max(adult_levels, key=lambda x: [
            'UNKNOWN', 
            'VERY_UNLIKELY', 
            'UNLIKELY', 
            'POSSIBLE', 
            'LIKELY', 
            'VERY_LIKELY'
        ].index(x))
    }

def _serialize_firestore_doc(doc_data: dict) -> dict:
    """Convert Firestore document data to JSON-serializable format."""
    serialized = {}
    for key, value in doc_data.items():
        if hasattr(value, 'timestamp'):  # Handle Firestore timestamps
            serialized[key] = value.isoformat()
        else:
            serialized[key] = value
    return serialized 