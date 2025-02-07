import Foundation
import Combine
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

class ShortFormFeedViewModel: ObservableObject {
    @Published private(set) var videos: [Video] = []
    @Published private(set) var loadingState: LoadingState = .idle
    
    private var currentPage = 0
    private var isLoading = false
    private var hasMoreVideos = true
    private let pageSize = 5
    private var lastDocument: DocumentSnapshot?
    private let isFollowingFeed: Bool
    
    init(isFollowingFeed: Bool = false) {
        self.isFollowingFeed = isFollowingFeed
    }
    
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
        if isFollowingFeed {
            guard let userId = Auth.auth().currentUser?.uid else {
                return [] // Return empty if not logged in
            }
            
            print("Fetching following feed for user: \(userId)")
            
            // Get following list
            let followingDocs = try await db.collection("users")
                .document(userId)
                .collection("following")
                .getDocuments()
            
            let followingIds = followingDocs.documents.map { $0.documentID }
            
            print("Following IDs found: \(followingIds)")
            
            if followingIds.isEmpty {
                print("No following found")
                return [] // Return empty if not following anyone
            }
            
            // First get all videos from followed users without ordering
            let allFollowedVideos = try await db.collection("videos")
                .whereField("userId", in: followingIds)
                .getDocuments()
            
            // Then sort them in memory
            let sortedVideos = allFollowedVideos.documents
                .sorted { doc1, doc2 in
                    let date1 = (doc1.data()["createdAt"] as? Timestamp)?.dateValue() ?? Date.distantPast
                    let date2 = (doc2.data()["createdAt"] as? Timestamp)?.dateValue() ?? Date.distantPast
                    return date1 > date2
                }
            
            // Apply pagination in memory
            let startIndex = currentPage * pageSize
            let endIndex = min(startIndex + pageSize, sortedVideos.count)
            
            // Check if we have more pages
            hasMoreVideos = endIndex < sortedVideos.count
            
            // Get the paginated subset
            guard startIndex < sortedVideos.count else { return [] }
            let paginatedDocs = Array(sortedVideos[startIndex..<endIndex])
            
            return try await processVideoDocuments(paginatedDocs)
            
        } else {
            // For You feed - fetch all videos without filtering by userId
            var query = db.collection("videos")
                .order(by: "createdAt", descending: true)
                .limit(to: pageSize)
            
            if let lastDocument = lastDocument {
                query = query.start(afterDocument: lastDocument)
            }
            
            let snapshot = try await query.getDocuments()
            self.lastDocument = snapshot.documents.last
            return try await processVideoDocuments(snapshot.documents)
        }
    }
    
    // Helper method to process video documents
    private func processVideoDocuments(_ documents: [QueryDocumentSnapshot]) async throws -> [Video] {
        try await withThrowingTaskGroup(of: Video?.self) { group in
            var videos: [Video] = []
            
            for document in documents {
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
                        throw VideoError.invalidData
                    }
                    
                    let thumbnailUrl = data["thumbnailUrl"] as? String
                    
                    // Fetch user data
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
    
    func reset() {
        videos = []
        currentPage = 0
        lastDocument = nil
        hasMoreVideos = true
        loadingState = .idle
        loadVideos()
    }
    
    // Public method to force refresh the feed
    func refreshFeed() {
        videos = []
        currentPage = 0
        lastDocument = nil
        hasMoreVideos = true
        isLoading = false
        loadingState = .idle
        
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
                print("Error refreshing videos: \(error)")
                await MainActor.run {
                    self.isLoading = false
                    self.loadingState = .error(error)
                }
            }
        }
    }
}

enum VideoError: Error {
    case invalidData
}