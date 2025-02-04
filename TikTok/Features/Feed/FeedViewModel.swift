import Foundation
import FirebaseStorage
import FirebaseFirestore

@MainActor
class FeedViewModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var isLoading = false
    @Published var error: Error?
    private let db = Firestore.firestore()
    
    func fetchVideos() async {
        isLoading = true
        
        do {
            let snapshot = try await db.collection("videos")
                .order(by: "createdAt", descending: true)
                .limit(to: 20)
                .getDocuments()
            
            await MainActor.run {
                self.videos = snapshot.documents.compactMap { document in
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
} 