import SwiftUI

struct HomeVideoOverlay: View {
    let videoUrl: String
    @State private var interaction = VideoInteraction(likes: 0, comments: 0, isLiked: false)
    @State private var showStackSelection = false
    
    var body: some View {
        HStack {
            Spacer()
            
            VStack(spacing: 20) {
                Spacer()
                    .frame(height: UIScreen.main.bounds.height * 0.45)
                
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
                Button(action: {}) {
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
                    .frame(height: 50)
            }
            .padding(.trailing, 16)
        }
        .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
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