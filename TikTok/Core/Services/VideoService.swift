import Firebase
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore
import FirebaseFunctions

class VideoService {
    static let shared = VideoService()
    
    #if DEBUG
    private let baseURL = "http://localhost:8000"
    #else
    private let baseURL = "https://your-production-url.com"  // Update this when deploying
    #endif
    
    // MARK: - Helper Methods
    private func createVideo(from dict: [String: Any]) throws -> Video {
        guard let id = dict["id"] as? String,
              let videoUrl = dict["videoUrl"] as? String,
              let caption = dict["caption"] as? String,
              let createdAtString = dict["createdAt"] as? String,
              let userId = dict["userId"] as? String,
              let likes = dict["likes"] as? Int,
              let comments = dict["comments"] as? Int,
              let shares = dict["shares"] as? Int else {
            throw NSError(domain: "VideoService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid video data"])
        }
        
        // Parse createdAt date
        let dateFormatter = ISO8601DateFormatter()
        guard let createdAt = dateFormatter.date(from: createdAtString) else {
            throw NSError(domain: "VideoService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid date format"])
        }
        
        // Create VideoAuthor
        let author = VideoAuthor(
            id: userId,
            username: dict["username"] as? String ?? "Unknown User",
            profileImageUrl: dict["profileImageUrl"] as? String
        )
        
        // Create Video
        return Video(
            id: id,
            videoUrl: videoUrl,
            caption: caption,
            createdAt: createdAt,
            userId: userId,
            author: author,
            likes: likes,
            comments: comments,
            shares: shares,
            thumbnailUrl: dict["thumbnailUrl"] as? String,
            tags: dict["tags"] as? [String] ?? []
        )
    }
    
    // MARK: - Video Analysis
    func analyzeVideoHealth(videoUrl: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "VideoService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let token = try await user.getIDToken()
        
        guard videoUrl.hasPrefix("gs://") else {
            throw NSError(
                domain: "VideoService",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid video URL format"]
            )
        }
        
        let endpoint = "\(baseURL)/videos/analyze"
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["videoUrl": videoUrl]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "VideoService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(
                domain: "VideoService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"]
            )
        }
        
        let responseDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let success = responseDict?["success"] as? Bool, success else {
            throw NSError(
                domain: "VideoService",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: responseDict?["error"] as? String ?? "Unknown error"]
            )
        }
    }
    
    // MARK: - Get Video Details
    func getVideoDetails(videoId: String) async throws -> Video {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "VideoService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let token = try await user.getIDToken()
        let endpoint = "\(baseURL)/videos/\(videoId)"
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "VideoService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server error"])
        }
        
        let responseDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let videoData = responseDict?["video"] as? [String: Any] else {
            throw NSError(domain: "VideoService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
        }
        
        return try createVideo(from: videoData)
    }
    
    // MARK: - Search Videos
    func searchVideos(query: String, limit: Int = 10) async throws -> [Video] {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "VideoService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let token = try await user.getIDToken()
        var urlComponents = URLComponents(string: "\(baseURL)/videos/search")!
        urlComponents.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "VideoService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server error"])
        }
        
        let responseDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let videosData = responseDict?["videos"] as? [[String: Any]] else {
            throw NSError(domain: "VideoService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
        }
        
        return try videosData.map { try createVideo(from: $0) }
    }
    
    // MARK: - Vectorize Video
    func vectorizeVideo(videoId: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "VideoService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let token = try await user.getIDToken()
        let endpoint = "\(baseURL)/videos/\(videoId)/vectorize"
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "VideoService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server error"])
        }
        
        let responseDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let success = responseDict?["success"] as? Bool, success else {
            throw NSError(
                domain: "VideoService",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: responseDict?["error"] as? String ?? "Unknown error"]
            )
        }
    }
    
    // MARK: - Get Recommendations
    func getRecommendations(
        userId: String,
        count: Int = 10,
        graphWeight: Double = 0.7
    ) async throws -> [Video] {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "VideoService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let token = try await user.getIDToken()
        
        var urlComponents = URLComponents(string: "\(baseURL)/videos/recommendations")!
        urlComponents.queryItems = [
            URLQueryItem(name: "user_id", value: userId),
            URLQueryItem(name: "count", value: String(count)),
            URLQueryItem(name: "graph_weight", value: String(graphWeight))
        ]
        
        guard let url = urlComponents.url else {
            throw NSError(domain: "VideoService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "VideoService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server error"])
        }
        
        let responseDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let success = responseDict?["success"] as? Bool,
              let videosData = responseDict?["videos"] as? [[String: Any]] else {
            throw NSError(domain: "VideoService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
        }
        
        return try videosData.map { try createVideo(from: $0) }
    }
} 