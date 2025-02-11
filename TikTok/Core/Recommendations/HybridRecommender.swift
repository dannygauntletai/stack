import Foundation

class HybridRecommender {
    private let graph = RecommendationGraph()
    private let videoService = VideoService.shared
    
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
        // Get recommendations directly from backend
        let recommendations = try await videoService.getRecommendations(
            userId: userId,
            count: count,
            graphWeight: graphWeight
        )
        
        // Map to video IDs
        return recommendations.map { $0.id }
    }
} 