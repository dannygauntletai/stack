import SwiftUI
import FirebaseFirestore
import FirebaseStorage

struct MessageBubble: View {
    let message: ChatMessage
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    @State private var videoThumbnails: [(id: String, url: String)] = []
    @EnvironmentObject private var feedViewModel: ShortFormFeedViewModel
    @State private var selectedVideo: Video?
    @State private var showFullScreenVideo = false
    @State private var isLoadingVideo = false
    @State private var feedbackSubmitted = false
    
    private let videoCache = NSCache<NSString, NSURL>()
    
    // Colors for feedback buttons
    private let inactiveColor = Color.gray.opacity(0.5)
    private let activeColor = Color.blue
    
    // Add property to track if this is the last part
    let isLastPart: Bool
    
    // Add computed property to determine if feedback buttons should show
    private var shouldShowFeedback: Bool {
        // Debug prints
        print("💭 Checking feedback for message: \(message.id)")
        print("📱 Is from current user: \(message.isFromCurrentUser)")
        print("🔍 Has run ID: \(message.feedback?.runId != nil)")
        
        // Only show feedback for AI messages (non-user messages)
        if message.isFromCurrentUser { return false }
        
        return !ChatService.shared.hasFeedbackBeenSubmitted(for: message.id)
    }
    
    func debugPrint(_ message: String) {
        print(message)
    }
    
    var body: some View {
        HStack {
            if message.isFromCurrentUser {
                Spacer()
            }
            
            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 8) {
                Text("") // Hidden debug text
                    .hidden()
                    .onAppear { debugPrint("🔍 Rendering message with \(message.videoIds.count) video IDs") }
                
                if let text = message.text {
                    Text(LocalizedStringKey(text))  // Use LocalizedStringKey to enable markdown
                        .textSelection(.enabled)    // Allow text selection
                        .padding(12)
                        .background(message.isFromCurrentUser ? Color.blue : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                if let imageURL = message.imageURL {
                    AsyncImage(url: URL(string: imageURL)) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } placeholder: {
                        ProgressView()
                    }
                    .background(message.isFromCurrentUser ? Color.blue : Color.gray.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                // Only show video thumbnails for recommendation messages
                if message.isRecommendationMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(videoThumbnails, id: \.id) { video in
                            Button(action: {
                                handleVideoTap(videoId: video.id)
                            }) {
                                ZStack {  // Add ZStack to overlay spinner on thumbnail
                                    AsyncImage(url: URL(string: video.url)) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 200, height: 300)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    } placeholder: {
                                        ProgressView()
                                    }
                                    
                                    if isLoadingVideo && selectedVideo?.id == video.id {  // Only show spinner for selected video
                                        ZStack {
                                            Color.black.opacity(0.5)
                                            ProgressView()
                                                .tint(.white)
                                        }
                                        .frame(width: 200, height: 300)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                            }
                        }
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                // Only show feedback buttons on the last part
                if shouldShowFeedback && !feedbackSubmitted && isLastPart {
                    HStack(spacing: 20) {
                        Button(action: submitPositiveFeedback) {
                            Image(systemName: "hand.thumbsup.fill")
                                .foregroundColor(inactiveColor)
                        }
                        
                        Button(action: submitNegativeFeedback) {
                            Image(systemName: "hand.thumbsdown.fill")
                                .foregroundColor(inactiveColor)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            
            if !message.isFromCurrentUser {
                Spacer()
            }
        }
        .padding(.vertical, 2)
        .onAppear {
            debugPrint("👋 MessageBubble appeared")
            if message.isRecommendationMessage {
                debugPrint("🔄 Loading thumbnails for recommendation message")
                videoThumbnails = []
                loadVideoThumbnails()
            }
        }
        .onDisappear {
            debugPrint("👋 MessageBubble disappeared")
            videoThumbnails = []
        }
        .fullScreenCover(isPresented: $showFullScreenVideo) {
            if let video = selectedVideo {
                VideoPlayerView(video: video)
                    .environmentObject(feedViewModel)
                    .background(.clear)
                    .preferredColorScheme(.dark)
            }
        }
    }
    
    private func handleVideoTap(videoId: String) {
        print("🎯 Video tap - ID before processing: \(videoId)")
        print("👆 Video tapped: \(videoId)")
        isLoadingVideo = true
        
        Task {
            do {
                let videoDoc = try await Firestore.firestore()
                    .collection("videos")
                    .document(videoId)
                    .getDocument()
                
                print("🎯 Video document data: \(videoDoc.data() ?? [:])")
                
                if let video = try await processVideoDocument(videoDoc) {
                    // Cache the video before showing player
                    if let cachedURL = try await cacheVideo(from: video.videoUrl) {
                        await MainActor.run {
                            selectedVideo = Video(
                                id: video.id,
                                videoUrl: cachedURL.absoluteString,
                                caption: video.caption,
                                createdAt: video.createdAt,
                                userId: video.userId,
                                author: video.author,
                                likes: video.likes,
                                comments: video.comments,
                                shares: video.shares,
                                thumbnailUrl: video.thumbnailUrl
                            )
                            isLoadingVideo = false
                            showFullScreenVideo = true
                        }
                    }
                }
            } catch {
                print("Error loading video: \(error)")
                await MainActor.run {
                    isLoadingVideo = false
                }
            }
        }
        
        presentationMode.wrappedValue.dismiss()
    }
    
    private func cacheVideo(from urlString: String) async throws -> URL? {
        guard let sourceURL = URL(string: urlString) else { return nil }
        
        // Check if already cached
        if let cachedURL = videoCache.object(forKey: urlString as NSString) as URL? {
            print("Using cached video: \(cachedURL)")
            return cachedURL
        }
        
        // Create local cache directory if needed
        let fileManager = FileManager.default
        let cacheDirectory = try fileManager.url(for: .cachesDirectory, 
                                               in: .userDomainMask,
                                               appropriateFor: nil,
                                               create: true)
        
        let videoName = sourceURL.lastPathComponent
        let cachedURL = cacheDirectory.appendingPathComponent(videoName)
        
        // Download and cache if not exists
        if !fileManager.fileExists(atPath: cachedURL.path) {
            print("Downloading video to cache: \(sourceURL)")
            
            let (downloadURL, _) = try await URLSession.shared.download(from: sourceURL)
            try fileManager.moveItem(at: downloadURL, to: cachedURL)
            
            print("Video cached successfully: \(cachedURL)")
        } else {
            print("Using existing cached video: \(cachedURL)")
        }
        
        videoCache.setObject(cachedURL as NSURL, forKey: urlString as NSString)
        return cachedURL
    }
    
    private func loadVideoThumbnails() {
        let db = Firestore.firestore()
        let storage = Storage.storage()
        
        print("🎯 Loading thumbnails for videoIds: \(message.videoIds)")
        
        for videoId in message.videoIds {
            print("🎯 Processing videoId: \(videoId)")
            // Skip if we already have this thumbnail
            if videoThumbnails.contains(where: { $0.id == videoId }) {
                print("⏭️ Skipping already loaded thumbnail for video: \(videoId)")
                continue
            }
            
            print("🔍 Fetching thumbnail for video: \(videoId)")
            db.collection("videos").document(videoId).getDocument { snapshot, error in
                if let error = error {
                    print("❌ Error loading video thumbnail: \(error.localizedDescription)")
                    return
                }
                
                print("🎯 Got document data: \(snapshot?.data() ?? [:])")
                
                if let data = snapshot?.data(),
                   let thumbnailPath = data["thumbnailUrl"] as? String {
                    print("📂 Got thumbnail path: \(thumbnailPath)")
                    
                    let storageRef = storage.reference(forURL: thumbnailPath)
                    storageRef.downloadURL { url, error in
                        if let error = error {
                            print("❌ Error getting download URL: \(error.localizedDescription)")
                            return
                        }
                        
                        if let downloadUrl = url {
                            print("🔗 Got download URL: \(downloadUrl.absoluteString)")
                            DispatchQueue.main.async {
                                // Only add if not already present
                                if !videoThumbnails.contains(where: { $0.id == videoId }) {
                                    videoThumbnails.append((id: videoId, url: downloadUrl.absoluteString))
                                    print("📱 Updated thumbnails array, now contains \(videoThumbnails.count) items")
                                }
                            }
                        }
                    }
                } else {
                    print("⚠️ No thumbnail URL found for video: \(videoId)")
                }
            }
        }
    }
    
    // Add helper method to process video document (copy from ShortFormFeedViewModel)
    private func processVideoDocument(_ document: DocumentSnapshot) async throws -> Video? {
        let data = document.data() ?? [:]
        
        guard let id = document.documentID as String?,
              let gsUrl = data["videoUrl"] as? String,
              let caption = data["caption"] as? String,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
              let userId = data["userId"] as? String,
              let likes = data["likes"] as? Int,
              let comments = data["comments"] as? Int,
              let shares = data["shares"] as? Int else {
            print("Invalid video data for ID: \(document.documentID)")
            return nil
        }
        
        let thumbnailUrl = data["thumbnailUrl"] as? String
        
        // Fetch user data
        let userDoc = try await Firestore.firestore()
            .collection("users")
            .document(userId)
            .getDocument()
        let userData = userDoc.data()
        
        let author = VideoAuthor(
            id: userId,
            username: userData?["username"] as? String ?? "Unknown User",
            profileImageUrl: userData?["profileImageUrl"] as? String
        )
        
        // Enhanced video URL handling
        let videoUrl: String
        if gsUrl.hasPrefix("gs://") {
            print("Converting gs:// URL to HTTP URL: \(gsUrl)")
            let storage = Storage.storage()
            let storageRef = storage.reference(forURL: gsUrl)
            
            do {
                let downloadURL = try await storageRef.downloadURL()
                videoUrl = downloadURL.absoluteString
                print("Successfully converted to download URL: \(videoUrl)")
            } catch {
                print("Error converting gs:// URL: \(error)")
                throw error
            }
        } else if gsUrl.hasPrefix("http") {
            videoUrl = gsUrl
            print("Using direct HTTP URL: \(videoUrl)")
        } else {
            print("Invalid video URL format: \(gsUrl)")
            throw VideoError.invalidVideoUrl
        }
        
        // Create video object with the processed URL
        let video = Video(
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
        
        print("Created video object with URL: \(videoUrl)")
        return video
    }
    
    private func submitPositiveFeedback() {
        guard let runId = message.feedback?.runId else { 
            print("❌ No run ID found for message: \(message.id)")
            return 
        }
        
        print("✅ Submitting positive feedback for message: \(message.id)")
        print("🔍 Using run ID: \(runId)")
        
        Task {
            do {
                let response = try await ChatService.shared.submitPositiveFeedback(
                    messageId: message.id,
                    runId: runId
                )
                
                if response.success {
                    ChatService.shared.markFeedbackSubmitted(for: message.id)
                    print("✨ Successfully submitted positive feedback")
                    await MainActor.run {
                        feedbackSubmitted = true
                    }
                }
            } catch {
                print("❌ Error submitting positive feedback: \(error)")
            }
        }
    }
    
    private func submitNegativeFeedback() {
        guard let runId = message.feedback?.runId else { 
            print("❌ No run ID found for message: \(message.id)")
            return 
        }
        
        Task {
            do {
                let response = try await ChatService.shared.submitNegativeFeedback(
                    messageId: message.id,
                    runId: runId
                )
                
                if response.success {
                    ChatService.shared.markFeedbackSubmitted(for: message.id)
                }
            } catch {
                print("Error submitting negative feedback: \(error)")
            }
        }
    }
}

#Preview {
    VStack {
        MessageBubble(message: ChatMessage(id: "1", text: "Hello there!", imageURL: nil, isFromCurrentUser: true, timestamp: Date(), senderId: "user1", sequence: 0), isLastPart: true)
        MessageBubble(message: ChatMessage(id: "2", text: "Hi! How are you?", imageURL: nil, isFromCurrentUser: false, timestamp: Date(), senderId: "user2", sequence: 0), isLastPart: true)
    }
} 