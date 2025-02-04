import SwiftUI

struct Comment: Identifiable {
    let id = UUID()
    let username: String
    let text: String
    let likes: Int
    let timeAgo: String
}

struct CommentsSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    // Test data
    private let testComments = [
        Comment(username: "user123", text: "This is amazing! 🔥", likes: 1234, timeAgo: "2h"),
        Comment(username: "tiktokfan", text: "Love this content! Keep it up", likes: 856, timeAgo: "3h"),
        Comment(username: "creator.official", text: "Thanks everyone for watching!", likes: 2341, timeAgo: "1h"),
        Comment(username: "swift_dev", text: "Great video 👏", likes: 432, timeAgo: "4h"),
        Comment(username: "music_lover", text: "What's the song name?", likes: 267, timeAgo: "5h")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Comments")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.primary)
                }
            }
            .padding()
            
            Divider()
            
            // Comments list
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(testComments) { comment in
                        CommentRow(comment: comment)
                    }
                }
                .padding()
            }
        }
        .background(Color(UIColor.systemBackground))
    }
}

struct CommentRow: View {
    let comment: Comment
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Profile picture
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 36)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(comment.username)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(comment.text)
                    .font(.subheadline)
                
                HStack(spacing: 16) {
                    Text(comment.timeAgo)
                    Text("\(comment.likes) likes")
                    Text("Reply")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Like button
            VStack(spacing: 4) {
                Image(systemName: "heart")
                    .foregroundColor(.secondary)
            }
        }
    }
} 