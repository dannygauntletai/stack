import SwiftUI

struct VideoOverlayView: View {
    let video: Video
    @ObservedObject var viewModel: FeedViewModel
    @Binding var interaction: VideoInteraction
    let onCommentsPress: () -> Void
    
    var body: some View {
        VStack(alignment: .center, spacing: 25) {
            // Like Button
            Button {
                toggleLike()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: viewModel.likedVideoIds.contains(video.id) ? "heart.fill" : "heart")
                        .font(.system(size: 35))
                        .foregroundStyle(viewModel.likedVideoIds.contains(video.id) ? .red : .white)
                    Text(formatCount(interaction.likes))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            
            // Comments Button
            Button(action: onCommentsPress) {
                VStack(spacing: 4) {
                    Image(systemName: "message")
                        .font(.system(size: 33))
                        .foregroundStyle(.white)
                    Text(formatCount(interaction.comments))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            
            // Stack Button
            Button {
                // Stack functionality
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "plus.square.fill.on.square.fill")
                        .font(.system(size: 33))
                        .foregroundStyle(.white)
                    Text("Stack")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            
            // Share Button
            Button {
                // Share functionality
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "arrowshape.turn.up.forward.fill")
                        .font(.system(size: 33))
                        .foregroundStyle(.white)
                    Text("Share")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
    }
    
    private func toggleLike() {
        interaction.isLiked.toggle()
        let newLikeCount = video.likes + (interaction.isLiked ? 1 : -1)
        interaction.likes = newLikeCount
        
        // Use the shared viewModel
        Task {
            await viewModel.toggleLike(videoId: video.id)
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