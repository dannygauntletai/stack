import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct StackedComponentsView: View {
    let category: StackCategory
    @StateObject private var viewModel = StackedComponentsViewModel()
    @State private var selectedVideo: Video? = nil
    @State private var showVideo = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 8),
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
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(viewModel.videos) { video in
                        ThumbnailCard(video: video, category: category) {
                            selectedVideo = video
                            showVideo = true
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
        }
        .background(Color.black)
        .navigationTitle(category.name)
        .task {
            await viewModel.fetchVideos(for: category.id)
        }
        .refreshable {
            await viewModel.fetchVideos(for: category.id)
        }
        .fullScreenCover(isPresented: $showVideo) {
            if let video = selectedVideo {
                VideoPlayerView(video: video, isPresented: $showVideo)
            }
        }
    }
}

private struct ThumbnailCard: View {
    let video: Video
    let category: StackCategory
    let action: () -> Void
    
    private let size = (UIScreen.main.bounds.width - 32) / 2
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                // Thumbnail
                Group {
                    if let thumbnailUrl = video.thumbnailUrl {
                        StorageImageView(gsURL: thumbnailUrl) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            thumbnailPlaceholder
                        }
                    } else {
                        thumbnailPlaceholder
                    }
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Score indicator
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                    Text("\(video.likes + video.comments)")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(8)
                .shadow(color: .black.opacity(0.3), radius: 3)
            }
        }
        .buttonStyle(ThumbnailButtonStyle())
    }
    
    private var thumbnailPlaceholder: some View {
        Rectangle()
            .fill(category.color.opacity(0.1))
            .overlay {
                Image(systemName: "play.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(category.color)
            }
    }
}

private struct ThumbnailButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

private struct VideoPlayerView: View {
    let video: Video
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            ShortFormFeed(initialVideo: video)
                .ignoresSafeArea()
            
            Button {
                isPresented = false
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
final class StackedComponentsViewModel: ObservableObject {
    @Published private(set) var videos: [Video] = []
    @Published private(set) var isLoading = false
    
    private let db = Firestore.firestore()
    
    func fetchVideos(for categoryId: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Get video IDs from user's stacks for this category
            let stacksRef = db.collection("users")
                .document(userId)
                .collection("stacks")
                .whereField("categoryId", isEqualTo: categoryId)
            
            let stacksSnapshot = try await stacksRef.getDocuments()
            let videoIds = stacksSnapshot.documents.compactMap { $0.data()["videoId"] as? String }
            
            guard !videoIds.isEmpty else {
                self.videos = []
                return
            }
            
            // Fetch videos
            let videosRef = db.collection("videos")
                .whereField(FieldPath.documentID(), in: videoIds)
            
            let videosSnapshot = try await videosRef.getDocuments()
            self.videos = videosSnapshot.documents.compactMap { doc in
                let data = doc.data()
                return Video(
                    id: doc.documentID,
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