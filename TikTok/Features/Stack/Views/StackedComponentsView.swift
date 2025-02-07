import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct StackedComponentsView: View {
    let category: StackCategory
    @StateObject private var viewModel = StackedComponentsViewModel()
    @State private var selectedVideo: Video? = nil
    @State private var showVideo = false
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
            } else if viewModel.videos.isEmpty {
                EmptyStateView(category: category)
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.videos) { video in
                        Button {
                            selectedVideo = video
                            showVideo = true
                        } label: {
                            VideoCard(video: video, category: category)
                        }
                        .buttonStyle(VideoButtonStyle(color: category.color))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .navigationTitle(category.name)
        .task {
            await viewModel.fetchVideos(for: category.id)
        }
        .refreshable {
            await viewModel.fetchVideos(for: category.id)
        }
        .fullScreenCover(isPresented: $showVideo) {
            ZStack(alignment: .topLeading) {
                if let video = selectedVideo {
                    ShortFormFeed(initialVideo: video)
                        .ignoresSafeArea()
                }
                
                // Back button
                Button {
                    showVideo = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(.black.opacity(0.3))
                        .clipShape(Circle())
                }
                .padding(.top, 60)
                .padding(.leading, 16)
            }
        }
    }
}

private struct VideoCard: View {
    let video: Video
    let category: StackCategory
    
    // Define fixed dimensions for consistent layout
    private let cardWidth = (UIScreen.main.bounds.width - 48) / 2 // Account for padding and spacing
    private let imageHeight: CGFloat = 180
    private let cardPadding: CGFloat = 12
    
    var body: some View {
        VStack(spacing: 8) {
            // Thumbnail container with fixed dimensions
            ZStack {
                if let thumbnailUrl = video.thumbnailUrl {
                    StorageImageView(gsURL: thumbnailUrl) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        placeholderView
                            .overlay {
                                ProgressView()
                                    .tint(category.color)
                            }
                    }
                } else {
                    placeholderView
                }
            }
            .frame(width: cardWidth - (cardPadding * 2), height: imageHeight)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Video Info with fixed width
            VStack(alignment: .leading, spacing: 4) {
                Text(video.caption)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 40) // Fixed height for 2 lines
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(category.color)
                        Text(formatCount(video.likes))
                            .foregroundStyle(.gray)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "message.fill")
                            .foregroundStyle(category.color)
                        Text(formatCount(video.comments))
                            .foregroundStyle(.gray)
                    }
                }
                .font(.system(size: 12))
            }
            .frame(width: cardWidth - (cardPadding * 2))
        }
        .frame(width: cardWidth, height: imageHeight + 80) // Fixed total height
        .padding(cardPadding)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var placeholderView: some View {
        Rectangle()
            .fill(category.color.opacity(0.1))
            .overlay {
                Image(systemName: "play.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(category.color)
            }
    }
    
    // Helper function to format counts (e.g., 1.2K, 4.5M)
    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

private struct VideoButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
            .shadow(
                color: color.opacity(configuration.isPressed ? 0.2 : 0.1),
                radius: configuration.isPressed ? 2 : 3,
                y: configuration.isPressed ? 1 : 2
            )
    }
}

private struct EmptyStateView: View {
    let category: StackCategory
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: category.icon)
                .font(.system(size: 60))
                .foregroundStyle(category.color)
            
            Text("No videos in this stack yet")
                .font(.headline)
            
            Text("Videos you add to this category will appear here")
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

@MainActor
class StackedComponentsViewModel: ObservableObject {
    @Published private(set) var videos: [Video] = []
    @Published private(set) var isLoading = false
    private let db = Firestore.firestore()
    
    func fetchVideos(for categoryId: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // First get the stacks for this category
            let stacksSnapshot = try await db.collection("users")
                .document(userId)
                .collection("stacks")
                .whereField("categoryId", isEqualTo: categoryId)
                .getDocuments()
            
            let videoIds = stacksSnapshot.documents.compactMap { doc -> String? in
                doc.data()["videoId"] as? String
            }
            
            if videoIds.isEmpty {
                self.videos = []
                return
            }
            
            // Then fetch the actual videos
            let videosSnapshot = try await db.collection("videos")
                .whereField(FieldPath.documentID(), in: videoIds)
                .getDocuments()
            
            self.videos = videosSnapshot.documents.compactMap { document in
                let data = document.data()
                let video = Video(
                    id: document.documentID,
                    videoUrl: data["videoUrl"] as? String ?? "",
                    caption: data["caption"] as? String ?? "",
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                    userId: data["userId"] as? String ?? "",
                    author: VideoAuthor(
                        id: data["userId"] as? String ?? "",
                        username: data["username"] as? String ?? "Unknown User",
                        profileImageUrl: data["profileImageUrl"] as? String
                    ),
                    likes: data["likes"] as? Int ?? 0,
                    comments: data["comments"] as? Int ?? 0,
                    shares: data["shares"] as? Int ?? 0,
                    thumbnailUrl: data["thumbnailUrl"] as? String
                )
                return video
            }
        } catch {
            print("Error fetching stacked videos: \(error)")
            self.videos = []
        }
    }
}

#Preview {
    NavigationView {
        StackedComponentsView(category: StackCategory(id: "1", name: "Favorites", icon: "star.fill", color: .yellow))
    }
} 