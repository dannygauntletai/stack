from google.cloud import videointelligence_v1 as videointelligence
from typing import Dict
import json
import traceback

class VideoService:
    @staticmethod
    async def analyze_video_content(video_url: str) -> Dict:
        print("<THOR_DEBUG> Starting _analyze_video_content")
        print(f"<THOR_DEBUG> Processing video URL: {video_url}")
        
        try:
            video_client = videointelligence.VideoIntelligenceServiceClient()
            
            if not video_url.startswith('gs://'):
                raise ValueError("Invalid video URL format")
                
            features = [
                videointelligence.Feature.LABEL_DETECTION,
                videointelligence.Feature.EXPLICIT_CONTENT_DETECTION
            ]
            
            request = videointelligence.AnnotateVideoRequest(
                input_uri=video_url,
                features=features
            )
            
            print("<THOR_DEBUG> Sending request to Video Intelligence API")
            operation = video_client.annotate_video(request)
            result = operation.result(timeout=480)
            print("<THOR_DEBUG> Received Video Intelligence results")

            # Create the analysis dictionary
            video_analysis = {
                'labels': [],
                'explicit_content': []
            }
            
            # Process labels
            for annotation in result.annotation_results:
                if hasattr(annotation, 'segment_label_annotations'):
                    video_analysis['labels'] = [
                        {
                            'description': label.entity.description,
                            'confidence': label.segments[0].confidence if label.segments else 0.0
                        }
                        for label in annotation.segment_label_annotations
                    ]
                
                # Process explicit content
                if hasattr(annotation, 'explicit_annotation'):
                    video_analysis['explicit_content'] = [
                        {
                            'timestamp': frame.time_offset.seconds,
                            'likelihood': frame.pornography_likelihood.name
                        }
                        for frame in annotation.explicit_annotation.frames
                    ]
            
            print("<THOR_DEBUG> Analysis complete")
            print(f"<THOR_DEBUG> Found {len(video_analysis['labels'])} labels")
            print(f"<THOR_DEBUG> Analysis result: {json.dumps(video_analysis, indent=2)}")
            
            return video_analysis
                
        except Exception as e:
            print(f"<THOR_DEBUG> ERROR in video analysis: {str(e)}")
            print(f"<THOR_DEBUG> Error traceback: ", traceback.format_exc())
            raise ValueError(f"Video analysis failed: {str(e)}")

    @staticmethod
    def _categorize_environment(labels) -> str:
        # Moving existing _categorize_environment implementation here
        pass

    @staticmethod
    def _assess_safety(safety_annotations: list) -> dict:
        # Moving existing _assess_safety implementation here
        pass 