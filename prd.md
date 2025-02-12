# Product Requirements Document: Supplement Recommender App

## Overview
This app is designed to enhance the user experience by suggesting supplement products that align with the content of user-uploaded videos. By analyzing video content and leveraging AI-powered recommendation techniques, users receive personalized supplement suggestions complete with product details and affiliate purchase links.

## Goals
- **Improve user engagement:** Offer personalized supplement recommendations based on video content.
- **Monetize content:** Integrate affiliate links via the Amazon Product Advertising API to generate referral revenue.
- **Enhance user value:** Provide detailed product insights and brand comparisons to help users make informed purchasing decisions.

## User Journey
1. **Video Upload:**  
   - The user uploads a video.
   - The app processes the video to determine its context.

2. **Video Content Analysis:**  
   - The app uses the [Google Cloud Video Intelligence API](https://cloud.google.com/video-intelligence) to detect objects, scenes, and actions within the video.
   - Detailed annotation data such as detected objects, activity labels, and scene transitions are collected as input for further analysis.

3. **Supplement Recommendation:**  
   - The annotated video data is chained with a call to an LLM (such as OpenAI’s GPT-4 or Google’s PaLM API).
   - The LLM interprets the video context (e.g., studying, working out) and generates appropriate supplement recommendations (e.g., omega‑3 for cognitive support, magnesium for recovery).

4. **Product Data Retrieval:**  
   - Using the recommendation, the Amazon Product Advertising API (PA API 5.0) is queried to fetch details for several supplement brands.
   - Data retrieved includes product descriptions, images, pricing, customer reviews, and affiliate links.

5. **Interaction & Presentation:**  
   - The user can swipe left on the video to seamlessly reveal the list of supplement recommendations.
   - Each supplement is displayed with its corresponding brand details, a short description, and a clickable purchase link that directs the user to Amazon with affiliate tracking.

## API Integrations & Technologies
1. **Google Cloud Video Intelligence API**  
   - **Purpose:** Analyze video content to extract labels, scenes, and actions.
   - **Requirements:** Detailed annotation data for understanding video context.

2. **LLM API (e.g., OpenAI’s GPT-4 or Google’s PaLM)**  
   - **Purpose:** Process and chain the video analysis data to generate supplement recommendations.
   - **Capabilities:** Handle multi-step prompts and provide natural language output with supplement suggestions.

3. **Amazon Product Advertising API (PA API 5.0)**  
   - **Purpose:** Search, retrieve, and display supplement products including images, descriptions, and pricing.
   - **Requirements:** Support for keyword-based search and affiliate tracking (e.g., Partner Tag).

4. **Optional Supplement & Nutrition Databases**  
   - **Purpose:** Provide enriched context such as dosage recommendations, benefits, and potential interactions.
   - **Examples:** Nutritionix API or similar health/supplement data providers.

## Technical Implementation
- **Frontend (iOS App):**
  - Swift-based UI to handle video upload and gesture-based interactions (e.g., swiping left to reveal recommendations).
  - Integration with the backend services to fetch analysis results and product data.
  
- **Backend Services:**
  - A microservice to orchestrate the video analysis, LLM processing, and product data retrieval.
  - Handle asynchronous processing of video content.
  - Implement robust error handling and user notifications in case of failure.
  
- **Data Flow:**
  1. User uploads a video.
  2. Video is processed by Google Cloud Video Intelligence, converting visual data into structured metadata.
  3. The metadata is sent to the LLM API to generate supplement suggestions.
  4. Recommendations are used to query the Amazon Product Advertising API for product details.
  5. The results are bundled and sent back to the iOS app to be displayed.

## Non-Functional Requirements
- **Performance:**  
  - Ensure video processing and API calls happen within acceptable response times.
  - Use asynchronous handling for video analysis and product data retrieval.
  
- **Scalability:**  
  - Design the backend to scale with user demand.
  - Implement caching mechanisms where feasible to reduce API calls.
  
- **Reliability & Error Handling:**  
  - Provide robust error messages and fallback options if any API call fails.
  - Monitor all external API calls for delays or data quality issues.

- **Data Security & Privacy:**  
  - Ensure compliance with relevant data protection regulations.
  - Secure API keys and sensitive information using best practices.

## Timeline & Milestones
1. **Phase 1: MVP Implementation**
   - Setup video upload interface and integration with Google Cloud Video Intelligence.
   - Implement basic chaining with LLM API for supplement recommendation.
   - Display sample results in a prototype UI.
   
2. **Phase 2: Product Data Integration**
   - Integrate with the Amazon Product Advertising API for live product data.
   - Finalize UI enhancements to support swipe interactions for supplement reveal.
   
3. **Phase 3: Optimization & Enrichment**
   - Add optional supplement & nutrition database integrations.
   - Improve error handling, caching, and scalability.
   - User testing and feedback integration to refine the experience.
