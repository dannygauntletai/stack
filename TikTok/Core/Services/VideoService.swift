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
    
    func analyzeVideoHealth(videoUrl: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(
                domain: "VideoService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]
            )
        }
        
        // Get and verify ID token
        let token = try await user.getIDToken()
        
        // Validate URL format
        guard videoUrl.hasPrefix("gs://tiktok-18d7a.firebasestorage.app/videos/") else {
            throw NSError(
                domain: "VideoService",
                code: 400,
                userInfo: [
                    NSLocalizedDescriptionKey: "Invalid video URL format",
                    "providedUrl": videoUrl
                ]
            )
        }
        
        // Create URL request
        guard let url = URL(string: "\(baseURL)/analyze_health") else {
            throw NSError(domain: "VideoService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["videoUrl": videoUrl]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Add before sending request
        print("Sending request to \(url)")
        print("Request body:", String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "")
        
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
        
        guard let responseDict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = responseDict["success"] as? Bool else {
            throw NSError(domain: "VideoService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
        }
        
        if !success {
            throw NSError(
                domain: "VideoService",
                code: 500,
                userInfo: [
                    NSLocalizedDescriptionKey: responseDict["error"] as? String ?? "Unknown error"
                ]
            )
        }
    }
} 