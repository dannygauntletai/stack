import Foundation
import FirebaseFirestore
import PineconeSwift

class EmbeddingService {
    private let db = Firestore.firestore()
    private let pinecone: PineconeSwift
    private let openAIKey: String
    private let embeddingModel = "text-embedding-3-small"
    
    init() {
        self.openAIKey = APIConfig.openAIKey
        self.pinecone = PineconeSwift(
            apikey: APIConfig.pineconeKey,
            baseURL: "https://\(APIConfig.pineconeProjectId)-\(APIConfig.pineconeEnvironment).svc.pinecone.io"
        )
    }
    
    /// Generate embedding for text using OpenAI API
    func generateEmbedding(for text: String) async throws -> [Float] {
        let url = URL(string: "https://api.openai.com/v1/embeddings")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "input": text,
            "model": embeddingModel
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(EmbeddingResponse.self, from: data)
        return response.data.first?.embedding ?? []
    }
    
    /// Store video embedding in Pinecone
    func storeVideoEmbedding(_ embedding: [Float], forVideo videoId: String) async throws {
        let embedResult = EmbedResult(
            index: 0,
            embedding: embedding.map { Double($0) },
            text: videoId
        )
        _ = try await pinecone.upsertVectors(
            with: [embedResult],
            namespace: "videos"
        )
    }
    
    /// Calculate cosine similarity between two embeddings
    func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0 }
        
        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let normA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let normB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        
        return dotProduct / (normA * normB)
    }
    
    /// Get similar videos based on embedding similarity
    func getSimilarVideos(to videoId: String, limit: Int = 10) async throws -> [(videoId: String, similarity: Float)] {
        let vector = try await getVideoEmbedding(videoId)
        let embedResult = EmbedResult(
            index: 0,
            embedding: vector.map { Double($0) },
            text: videoId
        )
        let results = try await pinecone.queryVectors(
            with: embedResult,
            namespace: "videos",
            topK: limit,
            includeMetadata: true
        )
        return results.map { match in
            (videoId: match.id, similarity: Float(match.score ?? 0))
        }
    }
    
    private func getVideoEmbedding(_ videoId: String) async throws -> [Float] {
        let vectors = try await pinecone.fetchVectors(with: [videoId], namespace: "videos")
        guard let vector = vectors.first else {
            throw EmbeddingError.embeddingNotFound
        }
        return vector.values.map { Float($0) }
    }
}

// MARK: - Supporting Types

struct EmbeddingResponse: Codable {
    let data: [EmbeddingData]
}

struct EmbeddingData: Codable {
    let embedding: [Float]
}

enum EmbeddingError: Error {
    case embeddingNotFound
    case invalidResponse
} 