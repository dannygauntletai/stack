import SwiftUI

struct HomeVideoOverlay: View {
    let video: Video
    @EnvironmentObject var viewModel: ShortFormFeedViewModel
    @State private var videoInteraction: VideoInteraction
    @State private var showStackSelection = false
    @State private var showComments = false
    @State private var showProductRecommendations = false
    @State private var isPerformingAction = false
    
    init(video: Video) {
        self.video = video
        self._videoInteraction = State(initialValue: VideoInteraction(
            watchTime: 0,
            isLiked: false,
            commentCount: video.comments,
            isStacked: false,
            isSkipped: false,
            userId: nil
        ))
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
            likes: video.likes,
            comments: videoInteraction.commentCount,
            shares: video.shares,
            thumbnailUrl: video.thumbnailUrl,
            tags: video.tags
        )
    }
    
    private var isLiked: Bool {
        viewModel.isVideoLiked(video.id)
    }
    
    // Update interaction when user changes
    private func updateInteraction() {
        videoInteraction = VideoInteraction(
            watchTime: videoInteraction.watchTime,
            isLiked: videoInteraction.isLiked,
            commentCount: videoInteraction.commentCount,
            isStacked: videoInteraction.isStacked,
            isSkipped: videoInteraction.isSkipped,
            userId: viewModel.currentUserId
        )
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Left side metadata
            VideoMetadataOverlay(
                author: video.author,
                caption: video.caption,
                videoId: video.id,
                tags: video.tags
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
                        Text(formatCount(video.comments))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                
                // Products Button (moved to Stack button's position)
                Button {
                    showProductRecommendations = true
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white)
                        Text("Products")
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
            CommentSheet(videoId: video.id)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showStackSelection) {
            StackSelectionModal(video: stackVideo)
        }
        .sheet(isPresented: $showProductRecommendations) {
            ProductRecommendationsSheet(
                supplements: video.supplementRecommendations,
                videoId: video.id,
                userId: video.userId
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            updateInteraction()
        }
        .onReceive(viewModel.$currentUserId) { _ in
            updateInteraction()
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