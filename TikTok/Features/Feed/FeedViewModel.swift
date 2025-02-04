import Foundation
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth

@MainActor
class FeedViewModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var likedVideoIds: Set<String> = []
    private let db = Firestore.firestore()
    
    func fetchVideos(initialVideo: Video? = nil) async {
        isLoading = true
        
        do {
            if let initialVideo = initialVideo {
                // Add initial video first
                videos = [initialVideo]
            }
            
            let snapshot = try await db.collection("videos")
                .order(by: "createdAt", descending: true)
                .limit(to: 20)
                .getDocuments()
            
            if let userId = Auth.auth().currentUser?.uid {
                let likedSnapshot = try await db.collection("users")
                    .document(userId)
                    .collection("likes")
                    .getDocuments()
                
                await MainActor.run {
                    self.likedVideoIds = Set(likedSnapshot.documents.map { $0.documentID })
                }
            }
            
            let fetchedVideos = snapshot.documents.compactMap { (document: QueryDocumentSnapshot) -> Video? in
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
            
            await MainActor.run {
                if initialVideo != nil {
                    self.videos += fetchedVideos.filter { $0.id != initialVideo?.id }
                } else {
                    self.videos = fetchedVideos
                }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    func updateVideoStats(videoId: String, likes: Int? = nil, comments: Int? = nil) {
        var data: [String: Any] = [:]
        if let likes = likes { data["likes"] = likes }
        if let comments = comments { data["comments"] = comments }
        
        guard !data.isEmpty else { return }
        
        db.collection("videos").document(videoId).updateData(data)
    }
    
    func toggleLike(videoId: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Check if video exists
        guard let index = videos.firstIndex(where: { $0.id == videoId }) else { return }
        
        // Check current like state
        let isCurrentlyLiked = likedVideoIds.contains(videoId)
        
        do {
            let batch = db.batch()
            let videoRef = db.collection("videos").document(videoId)
            let userLikeRef = db.collection("users")
                .document(userId)
                .collection("likes")
                .document(videoId)
            
            let increment = isCurrentlyLiked ? -1 : 1
            
            // Update video likes count
            batch.updateData([
                "likes": FieldValue.increment(Int64(increment))
            ], forDocument: videoRef)
            
            // Update user's likes collection
            if isCurrentlyLiked {
                batch.deleteDocument(userLikeRef)
                likedVideoIds.remove(videoId)
            } else {
                batch.setData(["timestamp": FieldValue.serverTimestamp()], forDocument: userLikeRef)
                likedVideoIds.insert(videoId)
            }
            
            // Commit the batch
            try await batch.commit()
            
            // Update local state
            await MainActor.run {
                videos[index].likes += increment
            }
        } catch {
            // Revert local state if server update fails
            await MainActor.run {
                if isCurrentlyLiked {
                    likedVideoIds.insert(videoId)
                } else {
                    likedVideoIds.remove(videoId)
                }
            }
        }
    }
} 