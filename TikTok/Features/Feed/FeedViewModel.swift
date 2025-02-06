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
    @Published var canLoadMore = true
    
    private let db = Firestore.firestore()
    private var lastDocument: DocumentSnapshot?
    private let pageSize = 10
    
    func fetchVideos(initialVideo: Video? = nil) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        
        do {
            if let initialVideo = initialVideo {
                videos = [initialVideo]
                lastDocument = nil
            }
            
            var query = db.collection("videos")
                .order(by: "createdAt", descending: true)
                .limit(to: pageSize)
            
            if let lastDoc = lastDocument {
                query = query.start(afterDocument: lastDoc)
            }
            
            let snapshot = try await query.getDocuments()
            
            if let userId = Auth.auth().currentUser?.uid {
                let likedSnapshot = try await db.collection("users")
                    .document(userId)
                    .collection("likes")
                    .getDocuments()
                
                await MainActor.run {
                    self.likedVideoIds = Set(likedSnapshot.documents.map { $0.documentID })
                }
            }
            
            let fetchedVideos = try await parseVideos(from: snapshot.documents)
            
            // Update pagination state
            lastDocument = snapshot.documents.last
            canLoadMore = !snapshot.documents.isEmpty && snapshot.documents.count == pageSize
            
            await MainActor.run {
                if initialVideo != nil {
                    self.videos += fetchedVideos.filter { $0.id != initialVideo?.id }
                } else {
                    self.videos = fetchedVideos
                }
                self.isLoading = false
            }
            
            // Prefetch next page videos
            if canLoadMore {
                Task {
                    await prefetchNextPageVideos()
                }
            }
        } catch {
            await MainActor.run {
                self.error = error as? NSError ?? NSError(
                    domain: "FeedViewModel",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to fetch videos: \(error.localizedDescription)"]
                )
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
    
    private func parseVideos(from documents: [QueryDocumentSnapshot]) throws -> [Video] {
        try documents.compactMap { document -> Video? in
            do {
                guard let videoUrl = document.get("videoUrl") as? String,
                      let caption = document.get("caption") as? String,
                      let userId = document.get("userId") as? String,
                      let createdAt = document.get("createdAt") as? Timestamp,
                      let likes = document.get("likes") as? Int,
                      let comments = document.get("comments") as? Int,
                      let shares = document.get("shares") as? Int
                else {
                    throw NSError(
                        domain: "FeedViewModel",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid document format for video ID: \(document.documentID)"]
                    )
                }
                
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
            } catch {
                print("Error parsing document \(document.documentID): \(error)")
                return nil
            }
        }
    }
    
    private func prefetchNextPageVideos() async {
        guard let lastDoc = lastDocument else { return }
        
        do {
            let nextSnapshot = try await db.collection("videos")
                .order(by: "createdAt", descending: true)
                .limit(to: pageSize)
                .start(afterDocument: lastDoc)
                .getDocuments()
            
            let nextVideos = try await parseVideos(from: nextSnapshot.documents)
            
            // Prefetch video URLs
            for video in nextVideos {
                VideoPlayerViewModel.prefetchVideo(url: video.videoUrl)
            }
        } catch {
            print("Failed to prefetch next page: \(error)")
        }
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
                
                self.error = error as? NSError ?? NSError(
                    domain: "FeedViewModel",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to toggle like: \(error.localizedDescription)"]
                )
            }
        }
    }
} 