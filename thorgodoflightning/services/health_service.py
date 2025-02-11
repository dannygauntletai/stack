from openai import OpenAI
from typing import Dict, Tuple
import json
import logging
import traceback
import os

logger = logging.getLogger(__name__)

class HealthService:
    @staticmethod
    async def analyze_health_impact(video_analysis: Dict) -> Tuple[float, Dict]:
        """Get health impact analysis from GPT-3.5 Turbo."""
        print("<THOR_DEBUG> Starting health impact analysis")
        
        try:
            openai_client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))
            
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
            
            # Using synchronous call since OpenAI client doesn't support async
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
            
            # Clean and ensure exactly 3 single-word tags
            if 'reasoning' in analysis and 'tags' in analysis['reasoning']:
                analysis['reasoning']['tags'] = HealthService._clean_tags(
                    analysis['reasoning']['tags'], 
                    score
                )
            
            print(f"<THOR_DEBUG> Parsed analysis: {json.dumps(analysis, indent=2)}")
            
            return score, analysis['reasoning']
            
        except Exception as e:
            print(f"<THOR_DEBUG> ERROR in health impact analysis: {str(e)}")
            print("<THOR_DEBUG> Error traceback: ", traceback.format_exc())
            raise ValueError(f"Health analysis failed: {str(e)}")

    @staticmethod
    def _clean_tags(tags: list, score: float = 0) -> list:
        """Clean and limit tags to exactly 3 single-word items."""
        # Filter to single words and lowercase
        clean_tags = [tag.strip().lower().split()[0] for tag in tags if tag.strip()]
        
        # Remove duplicates
        clean_tags = list(dict.fromkeys(clean_tags))
        
        # Ensure we have exactly 3 tags
        while len(clean_tags) < 3:
            if score > 0:
                clean_tags.append('healthy')
            elif score < 0:
                clean_tags.append('unhealthy')
            else:
                clean_tags.append('neutral')
                
        return clean_tags[:3]  # Limit to first 3 tags 