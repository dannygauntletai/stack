import SwiftUI

struct CommentSheet: View {
    @Environment(\.dismiss) private var dismiss
    let videoId: String
    @State private var comments: [Comment] = sampleComments
    @State private var newCommentText: String = ""
    
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
                    ForEach(comments) { comment in
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
                
                Button {
                    // TODO: Implement post comment
                    if !newCommentText.isEmpty {
                        postComment()
                    }
                } label: {
                    Text("Post")
                        .foregroundColor(!newCommentText.isEmpty ? .blue : .gray)
                }
            }
            .padding()
        }
    }
    
    private func postComment() {
        // TODO: Implement posting comment to backend
        newCommentText = ""
    }
}

struct CommentRow: View {
    let comment: Comment
    @State private var isLiked = false
    @State private var likeCount: Int
    
    init(comment: Comment) {
        self.comment = comment
        self._likeCount = State(initialValue: comment.likes)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Profile Image
            if let imageUrl = comment.profileImageUrl {
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
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
                
                Text(timeAgo(from: comment.createdAt))
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
    }
    
    private func handleLike() {
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1
        // TODO: Update like status in backend
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
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