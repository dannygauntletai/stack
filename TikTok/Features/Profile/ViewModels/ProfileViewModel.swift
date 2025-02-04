import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var userVideos: [Video] = []
    @Published var likedVideos: [Video] = []
    private let db = Firestore.firestore()
    
    func fetchUserContent() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            // Fetch user's videos
            let videosSnapshot = try await db.collection("videos")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            userVideos = videosSnapshot.documents.compactMap { document in
                guard let videoUrl = document.get("videoUrl") as? String,
                      let caption = document.get("caption") as? String,
                      let userId = document.get("userId") as? String,
                      let createdAt = document.get("createdAt") as? Timestamp,
                      let likes = document.get("likes") as? Int,
                      let comments = document.get("comments") as? Int,
                      let shares = document.get("shares") as? Int
                else { return nil }
                
                return Video(
                    id: document.documentID,
                    videoUrl: videoUrl,
                    caption: caption,
                    createdAt: createdAt.dateValue(),
                    userId: userId,
                    likes: likes,
                    comments: comments,
                    shares: shares
                )
            }
            
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
                    
                    let video = Video(
                        id: doc.documentID,
                        videoUrl: videoUrl,
                        caption: caption,
                        createdAt: createdAt.dateValue(),
                        userId: userId,
                        likes: likes,
                        comments: comments,
                        shares: shares
                    )
                    likedVideos.append(video)
                }
            }
        } catch {
            print("Error fetching user content: \(error)")
        }
    }
} 