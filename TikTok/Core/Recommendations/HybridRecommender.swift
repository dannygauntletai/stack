import Foundation

class HybridRecommender {
    private let graph = RecommendationGraph()
    private let embeddings = EmbeddingService()
    
    /// Get hybrid recommendations combining graph walks and content similarity
    /// - Parameters:
    ///   - userId: User to get recommendations for
    ///   - count: Number of recommendations to return
    ///   - graphWeight: Weight given to graph-based recommendations (0.0-1.0)
    func getRecommendations(
        forUser userId: String,
        count: Int,
        graphWeight: Double = 0.7
    ) async throws -> [String] {
        // Get recommendations from both sources
        async let graphRecs = graph.getRecommendations(forUser: userId, count: count)
        
        // Get user's most recently interacted videos for content-based recommendations
        let interactions = UserInteractionService.shared.getAllInteractions()
        let recentVideoId = interactions.watchTimes.keys.first ?? ""
        async let similarRecs = try embeddings.getSimilarVideos(to: recentVideoId, limit: count)
        
        // Await both results
        let (graphVideos, similarVideos) = try await (graphRecs, similarRecs)
        
        // Combine and score recommendations
        var finalScores: [String: Double] = [:]
        
        // Add graph-based scores
        for (index, videoId) in graphVideos.enumerated() {
            let score = Double(count - index) / Double(count) * graphWeight
            finalScores[videoId, default: 0] += score
        }
        
        // Add similarity-based scores
        let embeddingWeight = 1.0 - graphWeight
        for (videoId, similarity) in similarVideos {
            let score = Double(similarity) * embeddingWeight
            finalScores[videoId, default: 0] += score
        }
        
        // Sort by final scores and return top recommendations
        let recommendations = finalScores.sorted { $0.value > $1.value }
            .prefix(count)
            .map { $0.key }
        
        print("\n=== Hybrid Recommendations ===")
        print("Graph Recommendations:", graphVideos)
        print("Similar Videos:", similarVideos)
        print("Final Recommendations:", recommendations)
        print("============================\n")
        
        return Array(recommendations)
    }
} 