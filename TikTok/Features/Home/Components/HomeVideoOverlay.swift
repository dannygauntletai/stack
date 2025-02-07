import SwiftUI

struct HomeVideoOverlay: View {
    let video: Video
    @EnvironmentObject var viewModel: ShortFormFeedViewModel
    @State private var interaction: VideoInteraction
    @State private var showStackSelection = false
    @State private var showComments = false
    @State private var isPerformingAction = false
    
    init(video: Video) {
        self.video = video
        self._interaction = State(initialValue: VideoInteraction(
            likes: video.likes,
            comments: video.comments,
            isLiked: false
        ))
    }
    
    // Sample metadata for test videos
    private var metadata: (username: String, caption: String, profileImage: String?, tags: [String]) {
        (
            username: "creator123",
            caption: "Check out this awesome video! 🎥",
            profileImage: "https://picsum.photos/200",
            tags: ["Trending", "Viral"]  // Capitalized for better visual appearance
        )
    }
    
    // Create a stack video object with updated interaction counts
    private var stackVideo: Video {
        Video(
            id: video.id,
            videoUrl: video.videoUrl,
            caption: video.caption,
            createdAt: video.createdAt,
            userId: video.userId,
            author: video.author,
            likes: interaction.likes,
            comments: interaction.comments,
            shares: video.shares,
            thumbnailUrl: video.thumbnailUrl
        )
    }
    
    private var isLiked: Bool {
        viewModel.isVideoLiked(video.id)
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Left side metadata
            VideoMetadataOverlay(
                author: video.author,
                caption: video.caption,
                tags: []  // Parse tags from caption if needed
            )
            .frame(maxWidth: CGFloat.infinity, alignment: Alignment.leading)
            
            // Right side interaction buttons
            VStack(spacing: 20) {
                Spacer()
                
                // Like Button
                Button {
                    handleLike()
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 32))
                            .foregroundStyle(isLiked ? .red : .white)
                        Text(formatCount(video.likes))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .disabled(isPerformingAction)
                
                // Comments Button
                Button {
                    showComments = true
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "message")
                            .font(.system(size: 30))
                            .foregroundStyle(.white)
                        Text(formatCount(interaction.comments))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                
                // Stack Button
                Button {
                    showStackSelection = true
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "plus.square.fill.on.square.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white)
                        Text("Stack")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                
                // Share Button
                Button {
                    // Share functionality
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "arrowshape.turn.up.forward.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white)
                        Text("Share")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                
                Spacer()
                    .frame(height: 150)
            }
            .padding(.trailing, 16)
        }
        .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
        .sheet(isPresented: $showComments) {
            CommentSheet(videoId: video.videoUrl)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showStackSelection) {
            StackSelectionModal(video: stackVideo)
        }
    }
    
    private func handleLike() {
        guard !isPerformingAction else { return }
        isPerformingAction = true
        
        Task {
            do {
                try await viewModel.toggleLike(for: video)
            } catch {
                print("Error toggling like: \(error)")
            }
            isPerformingAction = false
        }
    }
    
    // Format counts like 1.2K, 4.5M etc
    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
} 