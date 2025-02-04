import SwiftUI

struct VideoOverlayView: View {
    let video: Video
    @Binding var interaction: VideoInteraction
    var onCommentsPress: () -> Void
    
    var body: some View {
        VStack {
            Spacer() // Add spacer to push buttons down
            
            VStack(spacing: 24) {
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
                Button(action: onCommentsPress) {
                    VStack(spacing: 4) {
                        Image(systemName: "message")
                            .font(.system(size: 26))
                            .foregroundStyle(.white)
                        Text(formatCount(interaction.comments))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
                
                // Add Button
                Button {
                    // Add functionality will be implemented later
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 26))
                            .foregroundStyle(.white)
                        Text("Add")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.trailing, -32) // Increased negative padding from -16 to -24
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