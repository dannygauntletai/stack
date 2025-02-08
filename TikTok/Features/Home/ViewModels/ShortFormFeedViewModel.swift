import Foundation
import Combine
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

class ShortFormFeedViewModel: ObservableObject {
    @Published private(set) var videos: [Video] = []
    @Published private(set) var loadingState: LoadingState = .idle
    @Published private(set) var likedVideoIds: Set<String> = []
    
    private var currentPage = 0
    private var isLoading = false
    private var hasMoreVideos = true
    private let pageSize = 5
    private var lastDocument: DocumentSnapshot?
    private let isFollowingFeed: Bool
    
    private var likesListener: ListenerRegistration?
    private var likeStatusCache = NSCache<NSString, NSNumber>()
    
    private var videoListeners: [String: ListenerRegistration] = [:]
    
    deinit {
        likesListener?.remove()
        removeAllVideoListeners()
    }
    
    init(isFollowingFeed: Bool = false) {
        self.isFollowingFeed = isFollowingFeed
        setupLikesListener()
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
    
    // Helper method to check like status with caching
    func isVideoLiked(_ videoId: String) -> Bool {
        // Check cache first for faster response
        if let cached = likeStatusCache.object(forKey: videoId as NSString) {
            return cached.boolValue
        }
        
        // Fall back to set and update cache
        let isLiked = likedVideoIds.contains(videoId)
        likeStatusCache.setObject(NSNumber(value: isLiked), forKey: videoId as NSString)
        return isLiked
    }
    
    private func setupLikesListener() {
        // Remove any existing listener
        likesListener?.remove()
        
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Setup real-time listener for likes collection
        likesListener = db.collection("users")
            .document(userId)
            .collection("likes")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self,
                      let snapshot = snapshot else {
                    print("Error listening for like updates: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                // Update liked video IDs
                let newLikedIds = Set(snapshot.documents.map { $0.documentID })
                
                // Clear cache and update with new values
                self.likeStatusCache.removeAllObjects()
                
                // Update local state on main thread
                DispatchQueue.main.async {
                    // Update liked video IDs set
                    self.likedVideoIds = newLikedIds
                    
                    // Update cache with new values - include both true and false states
                    for video in self.videos {
                        let isLiked = newLikedIds.contains(video.id)
                        self.likeStatusCache.setObject(NSNumber(value: isLiked), 
                                                     forKey: video.id as NSString)
                    }
                    
                    // Update video like counts if needed
                    self.updateVideoLikeCounts(oldLikes: self.likedVideoIds, newLikes: newLikedIds)
                }
            }
    }
    
    private func updateVideoLikeCounts(oldLikes: Set<String>, newLikes: Set<String>) {
        let added = newLikes.subtracting(oldLikes)
        let removed = oldLikes.subtracting(newLikes)
        
        for videoId in added {
            if let index = videos.firstIndex(where: { $0.id == videoId }) {
                videos[index].likes += 1
            }
        }
        
        for videoId in removed {
            if let index = videos.firstIndex(where: { $0.id == videoId }) {
                videos[index].likes -= 1
            }
        }
    }
    
    func toggleLike(for video: Video) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw VideoError.userNotAuthenticated
        }
        
        let videoRef = db.collection("videos").document(video.id)
        let userLikesRef = db.collection("users")
            .document(userId)
            .collection("likes")
            .document(video.id)
        
        let batch = db.batch()
        let isLiked = isVideoLiked(video.id)
        
        if isLiked {
            // Unlike
            batch.deleteDocument(userLikesRef)
            batch.updateData([
                "likes": FieldValue.increment(Int64(-1))
            ], forDocument: videoRef)
            
            // Update cache immediately for better UX
            likeStatusCache.setObject(NSNumber(value: false), forKey: video.id as NSString)
        } else {
            // Like
            batch.setData([
                "timestamp": FieldValue.serverTimestamp(),
                "videoId": video.id,
                "userId": userId
            ], forDocument: userLikesRef)
            
            batch.updateData([
                "likes": FieldValue.increment(Int64(1))
            ], forDocument: videoRef)
            
            // Update cache immediately for better UX
            likeStatusCache.setObject(NSNumber(value: true), forKey: video.id as NSString)
        }
        
        // Let the snapshot listener handle the state updates
        try await batch.commit()
    }
    
    private func removeAllVideoListeners() {
        videoListeners.values.forEach { $0.remove() }
        videoListeners.removeAll()
    }
    
    private func setupVideoListener(for video: Video) {
        // Remove existing listener if any
        videoListeners[video.id]?.remove()
        
        // Setup new listener
        let listener = db.collection("videos")
            .document(video.id)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self,
                      let snapshot = snapshot,
                      let data = snapshot.data(),
                      let likes = data["likes"] as? Int,
                      let comments = data["comments"] as? Int else { return }
                
                DispatchQueue.main.async {
                    if let index = self.videos.firstIndex(where: { $0.id == video.id }) {
                        // Update both likes and comments count
                        if self.videos[index].likes != likes {
                            self.videos[index].likes = likes
                        }
                        if self.videos[index].comments != comments {
                            self.videos[index].comments = comments
                        }
                    }
                }
            }
        
        videoListeners[video.id] = listener
    }
    
    func loadVideos() {
        guard !isLoading else { return }
        isLoading = true
        loadingState = .loading
        
        // Remove existing video listeners when loading new videos
        removeAllVideoListeners()
        
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
                    
                    // Setup listeners for new videos
                    newVideos.forEach { self.setupVideoListener(for: $0) }
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
                    
                    // Setup listeners for new videos
                    newVideos.forEach { self.setupVideoListener(for: $0) }
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
                    
                    // Extract tags from healthAnalysis and normalize them
                    var tags: [String] = []
                    if let healthAnalysis = data["healthAnalysis"] as? [String: Any],
                       let rawTags = healthAnalysis["tags"] as? [String] {
                        tags = rawTags.map { tag in
                            let normalizedTag = tag.lowercased().trimmingCharacters(in: .whitespaces)
                            return normalizedTag.hasPrefix("#") ? normalizedTag : "#\(normalizedTag)"
                        }
                    }
                    
                    // Fetch user data
                    let userDoc = try await self.db.collection("users").document(userId).getDocument()
                    let userData = userDoc.data()
                    
                    let author = VideoAuthor(
                        id: userId,
                        username: userData?["username"] as? String ?? "Unknown User",
                        profileImageUrl: userData?["profileImageUrl"] as? String
                    )
                    
                    // Safely handle the gsUrl
                    let videoUrl: String
                    if gsUrl.hasPrefix("gs://") {
                        // Handle gs:// URL
                        let storageRef = self.storage.reference(forURL: gsUrl)
                        videoUrl = try await storageRef.downloadURL().absoluteString
                    } else if gsUrl.hasPrefix("http") {
                        // Already a download URL
                        videoUrl = gsUrl
                    } else {
                        throw VideoError.invalidVideoUrl
                    }
                    
                    // Clean the URL by removing any double slashes (except for https://)
                    let cleanedUrl = videoUrl.replacingOccurrences(
                        of: "([^:])//",
                        with: "$1/",
                        options: .regularExpression
                    )
                    
                    return Video(
                        id: id,
                        videoUrl: cleanedUrl,
                        caption: caption,
                        createdAt: createdAt,
                        userId: userId,
                        author: author,
                        likes: likes,
                        comments: comments,
                        shares: shares,
                        thumbnailUrl: thumbnailUrl,
                        tags: tags
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
        likeStatusCache.removeAllObjects()
        removeAllVideoListeners() // Remove video listeners
        setupLikesListener()
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
        removeAllVideoListeners() // Remove video listeners
        
        Task {
            do {
                let newVideos = try await fetchVideos()
                await MainActor.run {
                    self.videos = newVideos
                    self.currentPage += 1
                    self.isLoading = false
                    self.hasMoreVideos = newVideos.count == self.pageSize
                    self.loadingState = newVideos.isEmpty ? .empty : .loaded
                    
                    // Setup listeners for new videos
                    newVideos.forEach { self.setupVideoListener(for: $0) }
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
    case invalidVideoUrl
    case userNotAuthenticated
}