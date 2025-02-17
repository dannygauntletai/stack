from openai import OpenAI
from typing import Dict, Tuple, List
import json
import logging
import traceback
from config import Config

logger = logging.getLogger(__name__)

class HealthService:
    @staticmethod
    async def analyze_health_impact(video_analysis: Dict) -> Tuple[float, Dict]:
        """Get health impact analysis from GPT-3.5 Turbo."""
        
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
            logger.debug("Raw GPT response received")
            
            analysis = json.loads(content)
            score = float(analysis['score'])
            
            # Clean and ensure exactly 3 single-word tags
            if 'reasoning' in analysis and 'tags' in analysis['reasoning']:
                analysis['reasoning']['tags'] = HealthService._clean_tags(
                    analysis['reasoning']['tags'], 
                    score
                )
            
            logger.debug("Analysis parsed successfully")
            
            # Generate a comprehensive one-line summary
            summary_prompt = f"""
            Create a comprehensive, detailed summary of this video's content. Focus on what is actually shown and discussed:
            
            1. Main topic or activity shown
            2. Key actions or processes demonstrated
            3. Objects, tools, or ingredients shown
            4. Environment or setting
            5. Step-by-step actions if applicable
            6. Results or outcomes shown
            7. Techniques or methods demonstrated
            8. Notable details or unique aspects
            
            Format the summary as a detailed paragraph that includes synonyms and related terms.
            Make it extremely detailed and keyword-rich for maximum searchability.
            
            Video Content:
            {json.dumps(video_analysis, indent=2)}
            """
            
            summary_response = openai_client.chat.completions.create(
                model="gpt-4-turbo-preview",
                messages=[
                    {"role": "system", "content": """You are a content analyzer. 
                    Create extremely detailed, searchable summaries that capture what is actually shown in the video.
                    Focus on observable content, actions, and details rather than interpretations.
                    Include specific terms, measurements, and alternatives to maximize findability.
                    Write in a natural, flowing style while incorporating as many relevant keywords as possible."""},
                    {"role": "user", "content": summary_prompt}
                ],
                temperature=0.3,
                max_tokens=1000
            )
            
            # Update the summary in the reasoning object
            analysis['reasoning']['summary'] = summary_response.choices[0].message.content.strip()

            return score, analysis['reasoning']
            
        except Exception as e:
            logger.error(f"Error in health impact analysis: {str(e)}")
            logger.error("Error traceback: ", traceback.format_exc())
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

    def _get_supplement_recommendations(self, activities: List[Dict], tags: List[str]) -> List[Dict]:
        """Get supplement recommendations based on activities and health tags"""
        
        # Expanded supplement database with categories
        SUPPLEMENT_DATABASE = {
            'performance': [
                {'name': 'Creatine Monohydrate', 'benefits': ['Muscle strength', 'Power output', 'Recovery']},
                {'name': 'Beta-Alanine', 'benefits': ['Endurance', 'Muscle fatigue reduction']},
                {'name': 'Caffeine', 'benefits': ['Energy', 'Focus', 'Performance']},
                {'name': 'BCAAs', 'benefits': ['Muscle recovery', 'Endurance', 'Protein synthesis']},
                {'name': 'Citrulline Malate', 'benefits': ['Blood flow', 'Endurance', 'Recovery']},
                {'name': 'Pre-workout Complex', 'benefits': ['Energy', 'Focus', 'Pump']}
            ],
            'recovery': [
                {'name': 'Whey Protein', 'benefits': ['Muscle recovery', 'Protein synthesis']},
                {'name': 'L-Glutamine', 'benefits': ['Recovery', 'Immune support']},
                {'name': 'ZMA', 'benefits': ['Sleep quality', 'Recovery', 'Hormone support']},
                {'name': 'Casein Protein', 'benefits': ['Overnight recovery', 'Protein synthesis']},
                {'name': 'Tart Cherry Extract', 'benefits': ['Recovery', 'Sleep', 'Anti-inflammation']},
                {'name': 'Collagen Peptides', 'benefits': ['Joint health', 'Recovery', 'Tissue repair']}
            ],
            'wellness': [
                {'name': 'Fish Oil (Omega-3)', 'benefits': ['Joint health', 'Brain function', 'Heart health']},
                {'name': 'Vitamin D3', 'benefits': ['Immune system', 'Bone health', 'Mood']},
                {'name': 'Magnesium', 'benefits': ['Sleep', 'Recovery', 'Muscle function']},
                {'name': 'Multivitamin', 'benefits': ['Overall health', 'Nutrient gaps', 'Energy']},
                {'name': 'Probiotics', 'benefits': ['Gut health', 'Immune system', 'Recovery']},
                {'name': 'Ashwagandha', 'benefits': ['Stress relief', 'Recovery', 'Hormone balance']}
            ],
            'specific': [
                {'name': 'Glucosamine & Chondroitin', 'benefits': ['Joint health', 'Mobility']},
                {'name': 'MCT Oil', 'benefits': ['Energy', 'Mental clarity', 'Fat metabolism']},
                {'name': 'L-Theanine', 'benefits': ['Focus', 'Calm energy', 'Mental clarity']},
                {'name': 'Turmeric/Curcumin', 'benefits': ['Joint health', 'Anti-inflammation']},
                {'name': 'Beta-Glucans', 'benefits': ['Immune support', 'Recovery']},
                {'name': 'Green Tea Extract', 'benefits': ['Metabolism', 'Energy', 'Antioxidants']}
            ]
        }

        try:
            # Map activities to supplement categories
            activity_category_map = {
                'strength_training': ['performance', 'recovery'],
                'cardio': ['performance', 'wellness'],
                'yoga': ['wellness', 'specific'],
                'hiit': ['performance', 'recovery'],
                'flexibility': ['recovery', 'specific'],
                'meditation': ['wellness'],
                'sports': ['performance', 'recovery', 'specific']
            }

            # Get relevant categories based on activities and tags
            relevant_categories = set()
            
            # Add categories from activities
            for activity in activities:
                activity_type = activity['label'].lower().replace(' ', '_')
                if activity_type in activity_category_map:
                    relevant_categories.update(activity_category_map[activity_type])

            # Add categories based on tags
            tag_category_map = {
                'strength': ['performance', 'recovery'],
                'endurance': ['performance', 'wellness'],
                'flexibility': ['recovery', 'specific'],
                'mental': ['wellness', 'specific'],
                'recovery': ['recovery', 'wellness']
            }
            
            for tag in tags:
                tag_lower = tag.lower()
                for key, categories in tag_category_map.items():
                    if key in tag_lower:
                        relevant_categories.update(categories)

            # Ensure we have at least one category
            if not relevant_categories:
                relevant_categories = {'wellness'}

            # Get random supplements from relevant categories
            import random
            recommendations = []
            
            # Try to get supplements from each relevant category
            for category in relevant_categories:
                category_supplements = SUPPLEMENT_DATABASE.get(category, [])
                if category_supplements:
                    # Get 1-2 random supplements from each relevant category
                    num_to_select = random.randint(1, 2)
                    selected = random.sample(category_supplements, min(num_to_select, len(category_supplements)))
                    recommendations.extend(selected)

            # Shuffle and limit to 4 unique supplements
            random.shuffle(recommendations)
            unique_recommendations = []
            seen_names = set()
            
            for supp in recommendations:
                if supp['name'] not in seen_names and len(unique_recommendations) < 4:
                    seen_names.add(supp['name'])
                    unique_recommendations.append(supp)

            return unique_recommendations

        except Exception as e:
            logger.error(f"Error generating supplement recommendations: {str(e)}")
            return [] 