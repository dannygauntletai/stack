import Foundation

class PineconeClient {
    private let apiKey: String
    private let environment: String = "gcp-starter"  // Your Pinecone environment
    private let projectId: String    // Your Pinecone project ID
    
    init(apiKey: String, projectId: String) {
        self.apiKey = apiKey
        self.projectId = projectId
    }
    
    func upsert(vectors: [[Float]], ids: [String]) async throws {
        let url = URL(string: "https://\(projectId)-\(environment).svc.pinecone.io/vectors/upsert")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Api-Key")
        
        let body = [
            "vectors": zip(ids, vectors).map { id, vector in
                ["id": id, "values": vector]
            }
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PineconeError.requestFailed
        }
    }
    
    func query(vector: [Float], topK: Int) async throws -> [(id: String, score: Float)] {
        let url = URL(string: "https://\(projectId)-\(environment).svc.pinecone.io/query")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Api-Key")
        
        let body = [
            "vector": vector,
            "topK": topK,
            "includeValues": false
        ] as [String : Any]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PineconeError.requestFailed
        }
        
        let result = try JSONDecoder().decode(QueryResponse.self, from: data)
        return result.matches.map { ($0.id, $0.score) }
    }
}

enum PineconeError: Error {
    case requestFailed
}

struct QueryResponse: Codable {
    let matches: [Match]
}

struct Match: Codable {
    let id: String
    let score: Float
} 