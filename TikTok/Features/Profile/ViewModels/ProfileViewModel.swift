import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var userVideos: [Video] = []
    @Published var likedVideos: [Video] = []
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    func setCachedUsername(_ username: String) {
        // Only set cached username if we don't have a user yet
        if user == nil {
            user = User(
                uid: "",  // Empty string as temporary ID
                username: username,
                firstName: "",
                lastName: "",
                email: "",
                profileImageUrl: nil,
                createdAt: Date(),
                followersCount: 0,
                followingCount: 0,
                restacksCount: 0
            )
        }
    }
    
    func fetchUserContent() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            // Fetch user data and stats
            let userDoc = try await db.collection("users").document(userId).getDocument()
            if let userData = userDoc.data() {
                // Get followers count
                let followersSnapshot = try await db.collection("users")
                    .document(userId)
                    .collection("followers")
                    .getDocuments()
                
                // Get following count
                let followingSnapshot = try await db.collection("users")
                    .document(userId)
                    .collection("following")
                    .getDocuments()
                
                // Get restacks count
                let restacksSnapshot = try await db.collection("users")
                    .document(userId)
                    .collection("restacks")
                    .getDocuments()
                
                let followersCount = followersSnapshot.documents
                    .filter { $0.documentID != "placeholder" }
                    .count
                
                let followingCount = followingSnapshot.documents
                    .filter { $0.documentID != "placeholder" }
                    .count
                
                let restacksCount = restacksSnapshot.documents
                    .filter { $0.documentID != "placeholder" }
                    .count
                
                // Create user with complete data from Firestore
                self.user = User(
                    uid: userId,
                    username: userData["username"] as? String ?? "",
                    firstName: userData["firstName"] as? String ?? "",
                    lastName: userData["lastName"] as? String ?? "",
                    email: userData["email"] as? String ?? "",
                    profileImageUrl: userData["profileImageUrl"] as? String,
                    createdAt: (userData["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                    followersCount: followersCount,
                    followingCount: followingCount,
                    restacksCount: restacksCount
                )
            }
            
            // Fetch user's videos
            userVideos = try await fetchUserVideos()
            
            // Fetch liked videos
            let likedSnapshot = try await db.collection("users")
                .document(userId)
                .collection("likes")
                .getDocuments()
            
            let videoIds = likedSnapshot.documents.map { $0.documentID }
            
            // Fetch video details for liked videos
            likedVideos = []
            for id in videoIds {
                if let doc = try? await db.collection("videos").document(id).getDocument(),
                   let videoUrl = doc.get("videoUrl") as? String,
                   let caption = doc.get("caption") as? String,
                   let userId = doc.get("userId") as? String,
                   let createdAt = doc.get("createdAt") as? Timestamp,
                   let likes = doc.get("likes") as? Int,
                   let comments = doc.get("comments") as? Int,
                   let shares = doc.get("shares") as? Int {
                    
                    let thumbnailUrl = doc.get("thumbnailUrl") as? String
                    
                    // Get user data for author
                    let userDoc = try await self.db.collection("users").document(userId).getDocument()
                    let userData = userDoc.data()
                    
                    let author = VideoAuthor(
                        id: userId,
                        username: userData?["username"] as? String ?? "Unknown User",
                        profileImageUrl: userData?["profileImageUrl"] as? String
                    )
                    
                    let video = Video(
                        id: doc.documentID,
                        videoUrl: videoUrl,
                        caption: caption,
                        createdAt: createdAt.dateValue(),
                        userId: userId,
                        author: author,
                        likes: likes,
                        comments: comments,
                        shares: shares,
                        thumbnailUrl: thumbnailUrl
                    )
                    likedVideos.append(video)
                }
            }
        } catch {
            print("Error fetching user content: \(error)")
        }
    }
    
    private func fetchUserVideos() async throws -> [Video] {
        guard let userId = Auth.auth().currentUser?.uid else { 
            throw ProfileError.userNotFound 
        }
        
        let snapshot = try await db.collection("videos")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()
        
        return try await withThrowingTaskGroup(of: Video?.self) { group in
            var videos: [Video] = []
            
            for document in snapshot.documents {
                group.addTask {
                    let data = document.data()
                    
                    guard let id = document.documentID as String?,
                          let gsUrl = data["videoUrl"] as? String,
                          let caption = data["caption"] as? String,
                          let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
                          let userId = data["userId"] as? String,
                          let likes = data["likes"] as? Int,
                          let comments = data["comments"] as? Int,
                          let shares = data["shares"] as? Int
                    else { 
                        throw ProfileError.invalidData 
                    }
                    
                    let thumbnailUrl = data["thumbnailUrl"] as? String
                    
                    // Get user data for author
                    let userDoc = try await self.db.collection("users").document(userId).getDocument()
                    let userData = userDoc.data()
                    
                    let author = VideoAuthor(
                        id: userId,
                        username: userData?["username"] as? String ?? "Unknown User",
                        profileImageUrl: userData?["profileImageUrl"] as? String
                    )
                    
                    // Convert gs:// URL to downloadable URL
                    let storageRef = self.storage.reference(forURL: gsUrl)
                    let videoUrl = try await storageRef.downloadURL().absoluteString
                    
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
                        thumbnailUrl: thumbnailUrl
                    )
                }
            }
            
            // Collect all non-nil videos
            for try await video in group {
                if let video = video {
                    videos.append(video)
                }
            }
            
            return videos
        }
    }
}

enum ProfileError: Error {
    case userNotFound
    case invalidData
} 