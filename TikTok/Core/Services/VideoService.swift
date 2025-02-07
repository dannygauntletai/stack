import Firebase
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore
import FirebaseFunctions

class VideoService {
    static let shared = VideoService()
    private let functions = Functions.functions()
    
    func analyzeVideoHealth(videoUrl: String) async throws {
        let data: [String: Any] = [
            "videoUrl": videoUrl
        ]
        
        // Just trigger the analysis and let the Cloud Function handle the rest
        let result = try await functions.httpsCallable("analyze_health").call(data)
        if let response = result.data as? [String: Any],
           let success = response["success"] as? Bool,
           !success {
            throw URLError(.badServerResponse)
        }
    }
} 