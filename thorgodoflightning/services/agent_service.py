from typing import Dict, Any
from services.agents.research_agent import ResearchAgent
from services.agents.chat_agent import ChatAgent
from services.db_service import DatabaseService
import logging
from langsmith import traceable
import langsmith as ls

logger = logging.getLogger(__name__)

class AgentService:
    def __init__(self, db_service: DatabaseService):
        self.db_service = db_service
        self.research_agent = ResearchAgent(db_service)
        self.chat_agent = ChatAgent(db_service)
    
    @traceable(project_name="thorgodoflightning", name="router")
    async def route_request(self, agent_type: str, input_data: Dict[str, Any]) -> Dict[str, Any]:
        """Route request to appropriate agent"""
        try:
            if agent_type == "research":
                response = await self.research_agent.process(input_data)
                # Get run ID from LangSmith
                run_tree = ls.get_current_run_tree()
                if run_tree:
                    response['run_id'] = str(run_tree.id)
                return response
            elif agent_type == "chat":
                response = await self.chat_agent.process(input_data)
                # Run ID is already included in the chat response
                return response
            else:
                raise ValueError(f"Unknown agent type: {agent_type}")
        except Exception as e:
            logger.error(f"Error routing request: {str(e)}")
            raise 