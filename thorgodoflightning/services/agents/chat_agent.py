from typing import Dict, Any
from services.agents.base_agent import BaseAgent
from services.db_service import DatabaseService
from services.vector_service import VectorService
from openai import OpenAI
from config import Config
import logging
import re
import time

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
        """Process the chat message and return AI response"""
        try:
            if not self.validate_input(input_data):
                raise ValueError("Missing required fields")
                
            content = input_data['content']
            
            # Check if this is a video request
            if self._is_video_request(content):
                # Get video recommendations
                vector_results = await VectorService.search_similar(content, 3)
                video_ids = [result['id'] for result in vector_results]
                videos = await self.db_service.get_videos_by_ids(video_ids)
                
                # Format video response
                response_text = "Here are some relevant videos:\n\n"
                for video in videos:
                    response_text += f"- {video.get('caption', 'Untitled')}\n"
                    response_text += f"  Video ID: {video['id']}\n\n"
            else:
                # Get chat response
                chat_response = self.openai_client.chat.completions.create(
                    model="gpt-4-turbo-preview",
                    messages=[
                        {"role": "system", "content": "You are a helpful health and wellness assistant."},
                        {"role": "user", "content": content}
                    ],
                    temperature=0.7,
                    max_tokens=500
                )
                response_text = chat_response.choices[0].message.content
            
            # Store only the AI response
            assistant_message = {
                'content': response_text,
                'type': 'text',
                'session_id': input_data['session_id'],
                'role': 'assistant',
                'sequence': input_data.get('sequence_number', 0),
                'timestamp': time.time(),
                'senderId': 'AI'
            }

            print("assistant_message", assistant_message)
            
            self.db_service.db.collection('messages').document().set(assistant_message)
            
            return {
                'success': True,
                'message': assistant_message
            }
            
        except Exception as e:
            logger.error(f"Error processing chat: {str(e)}", exc_info=True)
            raise
            
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