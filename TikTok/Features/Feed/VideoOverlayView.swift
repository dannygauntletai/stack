import SwiftUI

struct VideoOverlayView: View {
    let video: Video
    @ObservedObject var viewModel: FeedViewModel
    @Binding var interaction: VideoInteraction
    let onCommentsPress: () -> Void
    @State private var showStackSelection = false
    
    var body: some View {
        VStack(alignment: .center, spacing: 15) {
            Spacer()
                .frame(height: 250)  // Push content down from top
            
            // Like Button
            Button {
                toggleLike()
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: viewModel.likedVideoIds.contains(video.id) ? "heart.fill" : "heart")
                        .font(.system(size: 32))
                        .foregroundStyle(viewModel.likedVideoIds.contains(video.id) ? .red : .white)
                    Text(formatCount(interaction.likes))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            
            // Comments Button
            Button(action: onCommentsPress) {
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
            .sheet(isPresented: $showStackSelection) {
                StackSelectionModal(video: video)
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
                .frame(height: 140)  // Increased from 100 to 140 to lift share button higher
        }
        .padding(.trailing, 16)
        .frame(maxWidth: .infinity, alignment: .trailing)
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