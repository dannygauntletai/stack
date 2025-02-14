from typing import Dict, Any
from services.agents.base_agent import BaseAgent
from services.db_service import DatabaseService
from services.vector_service import VectorService
from openai import OpenAI
from config import Config
import logging
import re
import time
import json

logger = logging.getLogger(__name__)

class ChatAgent(BaseAgent):
    def __init__(self, db_service: DatabaseService):
        self.db_service = db_service
        self.openai_client = OpenAI(api_key=Config.OPENAI_API_KEY)
        
    def validate_input(self, input_data: Dict[str, Any]) -> bool:
        """Validate the input data"""
        required_fields = ['content', 'type', 'session_id']
        return all(field in input_data for field in required_fields)
        
    async def process(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        """Process the chat message using REACT pattern: Reason + Act"""
        try:
            if not self.validate_input(input_data):
                raise ValueError("Missing required fields")
                
            content = input_data['content']
            
            # First, analyze the user's request using LLM
            analysis = await self._analyze_request(content)
            print(f"🤔 Request analysis: {analysis}")
            
            # Based on analysis, determine action and execute
            if analysis['action'] == 'recommend_videos':
                response_text = await self._handle_video_recommendation(analysis['parsed_query'])
            else:
                response_text = await self._handle_general_chat(content)
            
            # Store response
            assistant_message = {
                'content': response_text,
                'type': 'text',
                'session_id': input_data['session_id'],
                'role': 'assistant',
                'sequence': input_data.get('sequence_number', 0),
                'timestamp': time.time(),
                'senderId': 'AI'
            }
            
            self.db_service.db.collection('messages').document().set(assistant_message)
            
            return {
                'success': True,
                'message': assistant_message
            }
            
        except Exception as e:
            logger.error(f"Error processing chat: {str(e)}", exc_info=True)
            raise
            
    async def _analyze_request(self, content: str) -> Dict:
        """Analyze user request using LLM to determine intent and extract relevant information"""
        try:
            response = self.openai_client.chat.completions.create(
                model="gpt-4-turbo-preview",
                messages=[
                    {"role": "system", "content": """Analyze the user's request and determine:
                    1. If they're asking for video recommendations
                    2. Extract specific requirements or preferences
                    3. Identify any constraints or filters
                    
                    Return a JSON with:
                    {
                        "action": "recommend_videos" or "general_chat",
                        "parsed_query": extracted search terms,
                        "requirements": {
                            "type": workout type if specified,
                            "difficulty": level if mentioned,
                            "duration": if specified,
                            "equipment": if mentioned,
                            "focus_area": specific body parts or skills
                        }
                    }"""},
                    {"role": "user", "content": content}
                ],
                response_format={ "type": "json_object" },
                temperature=0.7
            )
            
            return json.loads(response.choices[0].message.content)
            
        except Exception as e:
            logger.error(f"Error analyzing request: {str(e)}")
            return {"action": "general_chat", "parsed_query": content}
            
    async def _handle_video_recommendation(self, query: str) -> str:
        """Handle video recommendation requests"""
        # Use enhanced search with parsed query
        vector_results = await VectorService.search_k_similar(query, limit=1)
        video_ids = [result['id'] for result in vector_results]
        videos = await self.db_service.get_videos_by_ids(video_ids)
        
        # Format video response
        response_text = "Here are some relevant videos:\n"
        for video in videos:
            response_text += f"{video.get('caption', 'Untitled')}\n"
            response_text += f"  Video ID: {video['id']}\n\n"
            
        return response_text
        
    async def _handle_general_chat(self, content: str) -> str:
        """Handle general chat interactions"""
        chat_response = self.openai_client.chat.completions.create(
            model="gpt-4-turbo-preview",
            messages=[
                {"role": "system", "content": "You are a helpful health and wellness assistant."},
                {"role": "user", "content": content}
            ],
            temperature=0.7,
            max_tokens=500
        )
        return chat_response.choices[0].message.content

    def _is_video_request(self, content: str) -> bool:
        """Check if the user is asking for video recommendations"""
        video_keywords = [
            r"show.*video",
            r"find.*video",
            r"recommend.*video",
            r"similar video",
            r"related video",
            r"workout video",
            r"exercise video"
        ]
        
        content = content.lower()
        return any(re.search(pattern, content) for pattern in video_keywords) 