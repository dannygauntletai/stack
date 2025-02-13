from typing import Dict, Any
from services.agents.research_agent import ResearchAgent
from services.db_service import DatabaseService
import logging

logger = logging.getLogger(__name__)

class AgentService:
    def __init__(self, db_service: DatabaseService):
        self.db_service = db_service
        self.research_agent = ResearchAgent(db_service)
    
    async def route_request(self, agent_type: str, input_data: Dict[str, Any]) -> Dict[str, Any]:
        """Route request to appropriate agent"""
        if agent_type == "research":
            return await self.research_agent.process(input_data)
        else:
            raise ValueError(f"Unknown agent type: {agent_type}") 