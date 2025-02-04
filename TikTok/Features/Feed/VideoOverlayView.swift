import SwiftUI

struct VideoOverlayView: View {
    let video: Video
    @Binding var interaction: VideoInteraction
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack(alignment: .bottom) {
                // Caption and tags
                VStack(alignment: .leading) {
                    Text(video.caption)
                        .foregroundColor(.white)
                        .shadow(radius: 3)
                }
                .padding()
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 25) {
                    // Like Button
                    Button {
                        interaction.isLiked.toggle()
                        interaction.likes += interaction.isLiked ? 1 : -1
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: interaction.isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 35))
                                .foregroundStyle(interaction.isLiked ? .red : .white)
                            Text("\(interaction.likes)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    
                    // Comments Button
                    Button {
                        // Handle comments
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "message")
                                .font(.system(size: 35))
                                .foregroundStyle(.white)
                            Text("\(interaction.comments)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 40)
            }
        }
        .shadow(radius: 8)
    }
} 