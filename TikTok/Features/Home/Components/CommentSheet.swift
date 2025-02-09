import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

class CommentViewModel: ObservableObject {
    @Published private(set) var comments: [Comment] = []
    @Published var isLoading = false
    private var lastDocument: DocumentSnapshot?
    private let db = Firestore.firestore()
    private let videoId: String
    private let pageSize = 20
    private let storage = Storage.storage()
    private let interactionService = UserInteractionService.shared
    
    init(videoId: String) {
        self.videoId = videoId
    }
    
    private func processProfileImageUrl(_ url: String?) async throws -> String? {
        guard let url = url else { return nil }
        
        if url.hasPrefix("gs://") {
            let storageRef = storage.reference(forURL: url)
            return try await storageRef.downloadURL().absoluteString
        } else if url.hasPrefix("http") {
            return url
        }
        return nil
    }
    
    func loadComments() {
        guard !isLoading else { return }
        isLoading = true
        
        var query = db.collection("videos")
            .document(videoId)
            .collection("comments")
            .order(by: "createdAt", descending: true)
            .limit(to: pageSize)
        
        if let lastDoc = lastDocument {
            query = query.start(afterDocument: lastDoc)
        }
        
        query.getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error loading comments: \(error)")
                self.isLoading = false
                return
            }
            
            guard let documents = snapshot?.documents else {
                self.isLoading = false
                return
            }
            
            self.lastDocument = documents.last
            
            // Load user data for each comment
            Task {
                var newComments: [Comment] = []
                
                for document in documents {
                    let data = document.data()
                    
                    guard let userId = data["userId"] as? String,
                          let text = data["text"] as? String,
                          let timestamp = data["createdAt"] as? Timestamp,
                          let likes = data["likes"] as? Int else { continue }
                    
                    do {
                        let userDoc = try await self.db.collection("users")
                            .document(userId)
                            .getDocument()
                        
                        let userData = userDoc.data() ?? [:]  // Use empty dict as fallback
                        let username = userData["username"] as? String ?? "Unknown User"
                        let rawProfileImageUrl = userData["profileImageUrl"] as? String
                        
                        // Process profile image URL
                        let profileImageUrl = try await self.processProfileImageUrl(rawProfileImageUrl)
                        
                        let comment = Comment(
                            id: document.documentID,
                            videoId: self.videoId,
                            userId: userId,
                            text: text,
                            createdAt: timestamp.dateValue(),
                            likes: likes,
                            username: username,
                            profileImageUrl: profileImageUrl
                        )
                        
                        newComments.append(comment)
                    } catch {
                        print("Error processing comment: \(error)")
                    }
                }
                
                await MainActor.run {
                    if self.lastDocument == nil {
                        // First load
                        self.comments = newComments
                    } else {
                        // Append for pagination
                        self.comments.append(contentsOf: newComments)
                    }
                    self.isLoading = false
                }
            }
        }
    }
    
    func postComment(text: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw CommentError.userNotAuthenticated
        }
        
        let commentRef = db.collection("videos")
            .document(videoId)
            .collection("comments")
            .document()
        
        let videoRef = db.collection("videos").document(videoId)
        
        // Get user data first
        let userDoc = try await db.collection("users").document(userId).getDocument()
        let userData = userDoc.data() ?? [:]
        let username = userData["username"] as? String ?? "Unknown User"
        let rawProfileImageUrl = userData["profileImageUrl"] as? String
        let profileImageUrl = try await processProfileImageUrl(rawProfileImageUrl)
        
        let timestamp = FieldValue.serverTimestamp()
        
        let batch = db.batch()
        
        // Add comment
        batch.setData([
            "userId": userId,
            "text": text,
            "createdAt": timestamp,
            "likes": 0
        ], forDocument: commentRef)
        
        // Increment comment count on video
        batch.updateData([
            "comments": FieldValue.increment(Int64(1))
        ], forDocument: videoRef)
        
        try await batch.commit()
        
        // Create and append new comment locally
        await MainActor.run {
            let newComment = Comment(
                id: commentRef.documentID,
                videoId: self.videoId,
                userId: userId,
                text: text,
                createdAt: Date(), // Use current date as timestamp hasn't been set yet
                likes: 0,
                username: username,
                profileImageUrl: profileImageUrl
            )
            
            // Insert at the beginning since comments are ordered by newest first
            self.comments.insert(newComment, at: 0)
        }
        
        // Track the comment
        interactionService.trackComment(videoId: videoId)
    }
}

enum CommentError: Error {
    case userNotAuthenticated
}

struct CommentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CommentViewModel
    @State private var newCommentText: String = ""
    @State private var isPostingComment = false
    
    init(videoId: String) {
        self._viewModel = StateObject(wrappedValue: CommentViewModel(videoId: videoId))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Comments")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                }
            }
            .padding()
            
            Divider()
            
            // Comments List
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.comments) { comment in
                        CommentRow(comment: comment)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            
            Divider()
            
            // Comment Input
            HStack(spacing: 12) {
                TextField("Add comment...", text: $newCommentText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(isPostingComment)
                
                Button {
                    postComment()
                } label: {
                    Text("Post")
                        .foregroundColor(!newCommentText.isEmpty && !isPostingComment ? .blue : .gray)
                }
                .disabled(newCommentText.isEmpty || isPostingComment)
            }
            .padding()
        }
        .onAppear {
            viewModel.loadComments()
        }
    }
    
    private func postComment() {
        guard !newCommentText.isEmpty && !isPostingComment else { return }
        
        isPostingComment = true
        Task {
            do {
                try await viewModel.postComment(text: newCommentText)
                newCommentText = ""
            } catch {
                print("Error posting comment: \(error)")
            }
            isPostingComment = false
        }
    }
}

struct CommentRow: View {
    let comment: Comment
    @State private var isLiked = false
    @State private var likeCount: Int
    @State private var timeAgoText: String = ""
    let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
    init(comment: Comment) {
        self.comment = comment
        self._likeCount = State(initialValue: comment.likes)
        self._timeAgoText = State(initialValue: timeAgo(from: comment.createdAt))
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Profile Image
            if let imageUrl = comment.profileImageUrl {
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure(_):
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    case .empty:
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    @unknown default:
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 32, height: 32)
            }
            
            // Comment Content
            VStack(alignment: .leading, spacing: 4) {
                Text(comment.username)
                    .font(.system(size: 14, weight: .semibold))
                Text(comment.text)
                    .font(.system(size: 14))
                
                Text(timeAgoText)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Like Button
            VStack(spacing: 4) {
                Button {
                    handleLike()
                } label: {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 24))
                        .foregroundColor(isLiked ? .red : .gray)
                }
                
                Text("\(likeCount)")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .padding(.leading, 8)
        }
        .onReceive(timer) { _ in
            timeAgoText = timeAgo(from: comment.createdAt)
        }
    }
    
    private func handleLike() {
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1
        // TODO: Update like status in backend
    }
}

// Move timeAgo function to a utility extension
extension CommentRow {
    private func timeAgo(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .weekOfMonth, .day, .hour, .minute, .second], from: date, to: now)
        
        if let years = components.year, years > 0 {
            return "\(years)y"
        }
        if let months = components.month, months > 0 {
            return "\(months)mo"
        }
        if let weeks = components.weekOfMonth, weeks > 0 {
            return "\(weeks)w"
        }
        if let days = components.day, days > 0 {
            return "\(days)d"
        }
        if let hours = components.hour, hours > 0 {
            return "\(hours)h"
        }
        if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m"
        }
        if let seconds = components.second, seconds > 0 {
            return "\(seconds)s"
        }
        return "now"
    }
}

private let sampleComments = [
    Comment(
        id: "1",
        videoId: "video1",
        userId: "user1",
        text: "This is amazing! 🔥",
        createdAt: Date().addingTimeInterval(-3600),
        likes: 1234,
        username: "johndoe",
        profileImageUrl: "https://picsum.photos/100"
    ),
    Comment(
        id: "2",
        videoId: "video1",
        userId: "user2",
        text: "Love the way you edited this video! Can you share your process?",
        createdAt: Date().addingTimeInterval(-7200),
        likes: 856,
        username: "videoeditor_pro",
        profileImageUrl: nil
    ),
    Comment(
        id: "3",
        videoId: "video1",
        userId: "user3",
        text: "Been waiting for this! 👏👏👏",
        createdAt: Date().addingTimeInterval(-86400),
        likes: 2431,
        username: "sarah_smith",
        profileImageUrl: "https://picsum.photos/101"
    ),
    Comment(
        id: "4",
        videoId: "video1",
        userId: "user4",
        text: "The music choice is perfect",
        createdAt: Date().addingTimeInterval(-172800),
        likes: 657,
        username: "musiclover",
        profileImageUrl: "https://picsum.photos/102"
    ),
    Comment(
        id: "5",
        videoId: "video1",
        userId: "user5",
        text: "This showed up on my FYP and I'm not disappointed 😍",
        createdAt: Date().addingTimeInterval(-259200),
        likes: 1893,
        username: "tiktok_fan",
        profileImageUrl: nil
    )
] 