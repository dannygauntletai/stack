from openai import OpenAI
from typing import Dict, Tuple
import json
import logging
import traceback
from config import Config

logger = logging.getLogger(__name__)

class HealthService:
    @staticmethod
    async def analyze_health_impact(video_analysis: Dict) -> Tuple[float, Dict]:
        """Get health impact analysis from GPT-3.5 Turbo."""
        print("<THOR_DEBUG> Starting health impact analysis")
        
        try:
            logger.info("Starting health impact analysis")
            
            # Use Config instead of os.getenv
            api_key = Config.OPENAI_API_KEY
            if not api_key:
                raise ValueError("OpenAI API key not configured")
            
            openai_client = OpenAI(api_key=api_key)
            
            system_prompt = """You are primarily a nutrition and supplement expert, with additional expertise in longevity analysis for short-form videos (typically 15 seconds). 
            Your main task is to provide evidence-based supplement recommendations based on the video content and activities shown, while also analyzing its lifetime impact on life expectancy.

            When analyzing the video content, focus on these structured fields:
            - content_categories.primary_category: The main activity type (exercise, study, food, wellness, outdoor)
            - content_categories.activities: List of detected activities with confidence scores
            - content_categories.environment: The setting (indoor, outdoor, urban, natural)
            
            Base your supplement recommendations primarily on:
            1. The primary_category and activities detected
            2. The environment and context
            3. The confidence scores of detected activities

            Supplement Recommendation Guidelines (REQUIRED - always provide at least 2 recommendations):
            - For exercise activities:
              * Pre-workout supplements for high-intensity activities
              * Post-workout recovery supplements
              * Muscle recovery and growth support
            
            - For study/learning activities:
              * Cognitive enhancement supplements
              * Focus and memory support
              * Brain health nutrients
            
            - For food/cooking activities:
              * Digestive health supplements
              * Nutrient absorption support
              * Complementary vitamins/minerals
            
            - For wellness activities:
              * Stress reduction supplements
              * Sleep support if relevant
              * General well-being boosters
            
            - For outdoor activities:
              * Endurance support supplements
              * Sun protection nutrients
              * Electrolyte balance support

            Sample output for supplement recommendations:
            "supplement_recommendations": [
                {
                "name": "Vitamin A",
                "dosage": "5000 IU per day",
                "timing": "With breakfast",
                "reason": "Supports eye health and immune function, which can be beneficial when indoor activities limit natural sunlight exposure.",
                "caution": "Excessive intake can be harmful. Always follow recommended dosages."
                },
                {
                "name": "Omega-3 Fatty Acids",
                "dosage": "1000 mg daily",
                "timing": "With lunch or dinner",
                "reason": "Helps improve cognitive function and reduce inflammation, which is beneficial for recovery after physical activity.",
                "caution": "Consult with a healthcare provider if you are on blood-thinning medication."
                }
            ]

            Respond with valid JSON in this exact format (no other text):
            {
                "score": <integer_minutes>,
                "reasoning": {
                    "supplement_recommendations": [
                        {
                            "name": "<supplement_name>",
                            "dosage": "<recommended_dosage>",
                            "timing": "<when_to_take>",
                            "reason": "<why_recommended_based_on_detected_activities>",
                            "caution": "<safety_notes_if_any>"
                        },
                        {
                            "name": "<supplement_name_2>",
                            "dosage": "<recommended_dosage_2>",
                            "timing": "<when_to_take_2>",
                            "reason": "<why_recommended_based_on_detected_activities_2>",
                            "caution": "<safety_notes_if_any_2>"
                        }
                    ],
                    "summary": "<one-line impact summary>",
                    "content_type": "<primary_category_detected>",
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