import Foundation
import Combine
import FirebaseFirestore
import FirebaseStorage

class ShortFormFeedViewModel: ObservableObject {
    @Published private(set) var videos: [Video] = []
    @Published private(set) var loadingState: LoadingState = .idle
    
    private var currentPage = 0
    private var isLoading = false
    private var hasMoreVideos = true
    private let pageSize = 5
    private var lastDocument: DocumentSnapshot?
    
    enum LoadingState {
        case idle
        case loading
        case empty
        case loaded
        case error(Error)
    }
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    func loadVideos() {
        guard !isLoading else { return }
        isLoading = true
        loadingState = .loading
        
        // Reset pagination when loading fresh
        lastDocument = nil
        currentPage = 0
        
        Task {
            do {
                let newVideos = try await fetchVideos()
                await MainActor.run {
                    self.videos = newVideos
                    self.currentPage += 1
                    self.isLoading = false
                    self.hasMoreVideos = newVideos.count == self.pageSize
                    self.loadingState = newVideos.isEmpty ? .empty : .loaded
                }
            } catch {
                print("Error loading videos: \(error)")
                await MainActor.run {
                    self.isLoading = false
                    self.loadingState = .error(error)
                }
            }
        }
    }
    
    func loadMoreVideos() {
        guard !isLoading && hasMoreVideos else { return }
        isLoading = true
        
        Task {
            do {
                let newVideos = try await fetchVideos()
                await MainActor.run {
                    self.videos.append(contentsOf: newVideos)
                    self.currentPage += 1
                    self.isLoading = false
                    self.hasMoreVideos = newVideos.count == self.pageSize
                }
            } catch {
                print("Error loading more videos: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func fetchVideos() async throws -> [Video] {
        var query = db.collection("videos")
            .order(by: "createdAt", descending: true)
            .limit(to: pageSize)
        
        // If we have a last document, start after it for pagination
        if let lastDocument = lastDocument {
            query = query.start(afterDocument: lastDocument)
        }
        
        let snapshot = try await query.getDocuments()
        
        // Store the last document for next pagination
        self.lastDocument = snapshot.documents.last
        
        // Use async/await with Task.group to fetch all video URLs concurrently
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
                          let shares = data["shares"] as? Int else {
                        return nil
                    }
                    
                    let thumbnailUrl = data["thumbnailUrl"] as? String
                    
                    // Convert gs:// URL to downloadable URL
                    let storageRef = self.storage.reference(forURL: gsUrl)
                    let videoUrl = try await storageRef.downloadURL().absoluteString
                    
                    return Video(
                        id: id,
                        videoUrl: videoUrl,
                        caption: caption,
                        createdAt: createdAt,
                        userId: userId,
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