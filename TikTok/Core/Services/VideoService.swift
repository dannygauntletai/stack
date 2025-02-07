import Firebase
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore
import FirebaseFunctions

class VideoService {
    static let shared = VideoService()
    private let functions: Functions
    
    init() {
        // Initialize with region
        functions = Functions.functions(region: "us-central1")
        
        // Connect to local emulator
        // functions.useEmulator(withHost: "localhost", port: 5001)
    }
    
    func analyzeVideoHealth(videoUrl: String) async throws {
        print("\n=== Video Analysis Request Start ===")
        
        // Detailed auth verification
        guard let user = Auth.auth().currentUser else {
            print("❌ No authenticated user")
            throw NSError(
                domain: "VideoService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]
            )
        }
        
        print("=== Auth Details ===")
        print("User ID:", user.uid)
        print("Email:", user.email ?? "No email")
        print("Email Verified:", user.isEmailVerified)
        print("Provider ID:", user.providerID)
        
        // Get and verify ID token
        do {
            let token = try await user.getIDToken()
            print("\n=== Token Details ===")
            print("Token (first 32 chars):", String(token.prefix(32)) + "...")
            
            // Verify token is valid by making a test query to Firestore
            let db = Firestore.firestore()
            _ = try await db.collection("users").document(user.uid).getDocument()
            print("✅ Token verified with Firestore")
            
        } catch {
            print("❌ Token verification failed:", error)
            throw error
        }
        
        // First verify the video exists in Firebase Storage
        let storage = Storage.storage()
        let videoRef = storage.reference(forURL: videoUrl)
        
        print("Checking if video exists in Storage...")
        do {
            let metadata = try await videoRef.getMetadata()
            print("Video exists in Storage:")
            print("- Size:", metadata.size)
            print("- Content Type:", metadata.contentType ?? "unknown")
            print("- Created:", metadata.timeCreated ?? "unknown")
            print("- Path:", metadata.path ?? "unknown")
        } catch {
            print("❌ Error checking video in Storage:", error)
            throw error
        }
        
        // Validate URL format
        guard videoUrl.hasPrefix("gs://tiktok-18d7a.firebasestorage.app/videos/") else {
            print("❌ URL validation failed:")
            print("Expected prefix: gs://tiktok-18d7a.firebasestorage.app/videos/")
            print("Received URL:", videoUrl)
            throw NSError(
                domain: "VideoService",
                code: 400,
                userInfo: [
                    NSLocalizedDescriptionKey: "Invalid video URL format",
                    "providedUrl": videoUrl,
                    "expectedPrefix": "gs://tiktok-18d7a.firebasestorage.app/videos/"
                ]
            )
        }
        
        // Create request data for Firebase Functions
        do {
            print("\nAwaiting response...")
            // Get fresh token for auth
            let token = try await user.getIDToken(forcingRefresh: true)
            
            // Configure the function call
            let function = functions.httpsCallable("analyze_health")
            
            // Keep data simple - let Firebase handle auth
            let data = [
                "videoUrl": videoUrl
            ] as [String: Any]
            
            print("\nSending request to:")
            print("- Function: analyze_health")
            print("- Auth Token:", String(token.prefix(32)) + "...")
            print("- Data:", data)
            
            let result = try await function.call(data)
            
            guard let responseDict = result.data as? [String: Any] else {
                print("❌ Failed to parse response as dictionary")
                throw NSError(domain: "VideoService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
            }
            
            print("\nParsed response:", responseDict)
            
            guard let success = responseDict["success"] as? Bool else {
                print("❌ Missing 'success' field in response")
                throw NSError(
                    domain: "VideoService",
                    code: 500,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Missing success field",
                        "response": responseDict
                    ]
                )
            }
            
            if !success {
                print("❌ Function returned error:")
                print("Error:", responseDict["error"] as? String ?? "Unknown error")
                print("Full response:", responseDict)
                throw NSError(
                    domain: "VideoService",
                    code: 500,
                    userInfo: [
                        NSLocalizedDescriptionKey: responseDict["error"] as? String ?? "Unknown error",
                        "fullResponse": responseDict
                    ]
                )
            }
            
            print("✅ Video analysis completed successfully")
            
        } catch let functionsError as NSError {
            print("\n❌ Cloud Function Error Details:")
            print("- Domain:", functionsError.domain)
            print("- Code:", functionsError.code)
            print("- Description:", functionsError.localizedDescription)
            
            // Try to extract the detailed error response from the Cloud Function
            if let responseData = functionsError.userInfo["FIRFunctionsErrorDetailsKey"] as? [String: Any] {
                print("\nCloud Function Response Details:")
                print("- Success:", responseData["success"] ?? "N/A")
                print("- Error:", responseData["error"] ?? "N/A")
                if let details = responseData["details"] as? [String: Any] {
                    print("- Raw Data:", details["raw_data"] ?? "N/A")
                    print("- Error Details:", details["error"] ?? "N/A")
                }
            }
            
            print("- Video URL:", videoUrl)
            print("=== Video Analysis Request End ===\n")
            throw functionsError
            
        } catch {
            print("\n❌ Unexpected Error:")
            print("- Error:", error)
            print("- Description:", (error as NSError).localizedDescription)
            print("- Domain:", (error as NSError).domain)
            print("- Code:", (error as NSError).code)
            print("- User Info:", (error as NSError).userInfo)
            print("- Video URL:", videoUrl)
            print("=== Video Analysis Request End ===\n")
            throw error
        }
    }
} 