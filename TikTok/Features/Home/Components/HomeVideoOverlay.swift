import SwiftUI

struct HomeVideoOverlay: View {
    let video: Video
    @State private var interaction: VideoInteraction
    @State private var showStackSelection = false
    @State private var showComments = false
    
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
            likes: interaction.likes,
            comments: interaction.comments,
            shares: video.shares,
            thumbnailUrl: video.thumbnailUrl
        )
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Left side metadata
            VideoMetadataOverlay(
                username: metadata.username,
                caption: metadata.caption,
                profileImageUrl: metadata.profileImage,
                tags: metadata.tags
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Right side interaction buttons
            VStack(spacing: 20) {
                Spacer()
                
                // Like Button
                Button {
                    interaction.isLiked.toggle()
                    interaction.likes += interaction.isLiked ? 1 : -1
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: interaction.isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 32))
                            .foregroundStyle(interaction.isLiked ? .red : .white)
                        Text(formatCount(interaction.likes))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                
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