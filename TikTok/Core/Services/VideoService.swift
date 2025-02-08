import Firebase
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore
import FirebaseFunctions

class VideoService {
    static let shared = VideoService()
    private let functions: Functions
    
    init() {
        functions = Functions.functions(region: "us-central1")
        
        #if DEBUG
        functions.useEmulator(withHost: "localhost", port: 5001)
        #endif
    }
    
    func analyzeVideoHealth(videoUrl: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(
                domain: "VideoService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]
            )
        }
        
        // Get and verify ID token
        do {
            let token = try await user.getIDToken()
            let db = Firestore.firestore()
            _ = try await db.collection("users").document(user.uid).getDocument()
        } catch {
            throw error
        }
        
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
        
        do {
            let token = try await user.getIDToken(forcingRefresh: true)
            let function = functions.httpsCallable("analyze_health")
            let data = ["videoUrl": videoUrl] as [String: Any]
            
            let result = try await function.call(data)
            
            guard let responseDict = result.data as? [String: Any],
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
        } catch {
            throw error
        }
    }
} 