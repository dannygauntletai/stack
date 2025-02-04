import SwiftUI

struct VideoOverlayView: View {
    let video: Video
    @Binding var interaction: VideoInteraction
    
    var body: some View {
        VStack(spacing: 20) {
            // Like Button
            Button {
                interaction.isLiked.toggle()
                interaction.likes += interaction.isLiked ? 1 : -1
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: interaction.isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 28))
                        .foregroundStyle(interaction.isLiked ? .red : .white)
                    Text(formatCount(interaction.likes))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            
            // Comments Button
            Button {
                // Handle comments
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "message")
                        .font(.system(size: 26))
                        .foregroundStyle(.white)
                    Text(formatCount(interaction.comments))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
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