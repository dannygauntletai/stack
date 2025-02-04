import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Foundation

struct CommentsSheet: View {
    let video: Video
    @StateObject var viewModel: CommentsViewModel
    @State private var commentText = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    
    init(video: Video, onCommentAdded: @escaping () -> Void) {
        self.video = video
        _viewModel = StateObject(wrappedValue: CommentsViewModel(onCommentAdded: onCommentAdded))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.comments) { comment in
                                CommentRow(comment: comment)
                            }
                        }
                        .padding()
                    }
                }
                
                // Comment input
                HStack(spacing: 12) {
                    TextField("Add comment...", text: $commentText)
                        .textFieldStyle(.roundedBorder)
                        .focused($isFocused)
                    
                    Button(action: submitComment) {
                        Text("Post")
                            .fontWeight(.semibold)
                    }
                    .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                .background(Color(.systemBackground))
                .overlay(Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.2)), alignment: .top)
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            await viewModel.fetchComments(for: video.id)
        }
        .onChange(of: viewModel.commentAdded) { oldValue, newValue in
            if newValue {
                commentText = ""
                isFocused = false
            }
        }
    }
    
    private func submitComment() {
        guard !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        Task {
            await viewModel.addComment(to: video.id, text: commentText)
        }
    }
}

@MainActor
class CommentsViewModel: ObservableObject {
    @Published var comments: [Comment] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var commentAdded = false
    private let db = Firestore.firestore()
    let onCommentAdded: () -> Void
    
    init(onCommentAdded: @escaping () -> Void = {}) {
        self.onCommentAdded = onCommentAdded
    }
    
    func fetchComments(for videoId: String) async {
        isLoading = true
        
        do {
            let snapshot = try await db.collection("videos")
                .document(videoId)
                .collection("comments")
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            await MainActor.run {
                self.comments = snapshot.documents.compactMap { document in
                    guard 
                        let userId = document.get("userId") as? String,
                        let text = document.get("text") as? String,
                        let createdAt = document.get("createdAt") as? Timestamp,
                        let likes = document.get("likes") as? Int,
                        let username = document.get("username") as? String
                    else { return nil }
                    
                    return Comment(
                        id: document.documentID,
                        videoId: videoId,
                        userId: userId,
                        text: text,
                        createdAt: createdAt.dateValue(),
                        likes: likes,
                        username: username,
                        profileImageUrl: document.get("profileImageUrl") as? String
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
    
    func addComment(to videoId: String, text: String) async {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        do {
            let batch = db.batch()
            
            // Create comment document
            let commentRef = db.collection("videos")
                .document(videoId)
                .collection("comments")
                .document()
            
            let comment = Comment(
                id: commentRef.documentID,
                videoId: videoId,
                userId: currentUser.uid,
                text: text,
                createdAt: Date(),
                likes: 0,
                username: currentUser.displayName ?? "User",
                profileImageUrl: currentUser.photoURL?.absoluteString
            )
            
            batch.setData(comment.dictionary, forDocument: commentRef)
            
            // Increment video comment count
            let videoRef = db.collection("videos").document(videoId)
            batch.updateData([
                "comments": FieldValue.increment(Int64(1))
            ], forDocument: videoRef)
            
            try await batch.commit()
            
            await MainActor.run {
                self.comments.insert(comment, at: 0)
                self.commentAdded = true
                self.onCommentAdded()
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1))
                    self.commentAdded = false
                }
            }
        } catch {
            print("Error adding comment: \(error)")
        }
    }
}

struct CommentRow: View {
    let comment: Comment
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Profile Image
            if let imageUrl = comment.profileImageUrl {
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.gray)
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 36))
                    .frame(width: 36, height: 36)
                    .foregroundStyle(.gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(comment.username)
                    .font(.system(size: 14, weight: .semibold))
                Text(comment.text)
                    .font(.system(size: 14))
                
                Text(comment.createdAt, style: .relative)
                    .font(.system(size: 12))
                    .foregroundStyle(.gray)
            }
            
            Spacer()
            
            // Like button with correct sizing
            VStack(spacing: 4) {
                Image(systemName: "heart")
                    .font(.system(size: 24))
                Text("\(comment.likes)")
                    .font(.system(size: 12))
            }
            .foregroundStyle(.gray)
        }
    }
} 