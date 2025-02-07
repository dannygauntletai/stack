import SwiftUI

struct HealthAnalysisView: View {
    let video: Video
    @ObservedObject var viewModel: StackedComponentsViewModel
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Thumbnail
                    Group {
                        if let thumbnailUrl = video.thumbnailUrl {
                            StorageImageView(gsURL: thumbnailUrl) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 200)
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 200)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, -20) // Negative padding to extend beyond parent padding
                    
                    VStack(alignment: .leading, spacing: 32) {
                        // Health Impact Score
                        if let score = viewModel.healthImpactScore(for: video.id) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(Int(score))")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.white)
                                Text("minutes impact on lifespan")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 8)
                        }
                        
                        if let analysis = viewModel.healthAnalysis(for: video.id) {
                            // Content Type & Summary
                            VStack(alignment: .leading, spacing: 12) {
                                Text(analysis.contentType)
                                    .font(.system(size: 24, weight: .medium))
                                Text(analysis.summary)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .lineSpacing(4)
                            }
                            
                            // Benefits
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Benefits")
                                    .font(.system(size: 20, weight: .semibold))
                                ForEach(analysis.benefits, id: \.self) { benefit in
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.green)
                                            .frame(width: 20)
                                        Text(benefit)
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                            .lineSpacing(4)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            
                            // Risks
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Risks")
                                    .font(.system(size: 20, weight: .semibold))
                                ForEach(analysis.risks, id: \.self) { risk in
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.red)
                                            .frame(width: 20)
                                        Text(risk)
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                            .lineSpacing(4)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            
                            // Recommendations
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Recommendations")
                                    .font(.system(size: 20, weight: .semibold))
                                ForEach(analysis.recommendations, id: \.self) { recommendation in
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: "lightbulb.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.yellow)
                                            .frame(width: 20)
                                        Text(recommendation)
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                            .lineSpacing(4)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, UITabBarController().tabBar.frame.height)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Health Analysis")
        .background(Color.black)
    }
}

// Helper for custom corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    let previewVideo = Video(
        id: "test",
        videoUrl: "",
        caption: "Test Video",
        createdAt: Date(),
        userId: "user1",
        author: VideoAuthor(id: "user1", username: "Test User", profileImageUrl: nil),
        likes: 0,
        comments: 0,
        shares: 0,
        thumbnailUrl: "gs://tiktok-18d7a.firebasestorage.app/videos/thumbnail.jpg"
    )
    
    return HealthAnalysisView(
        video: previewVideo,
        viewModel: StackedComponentsViewModel(),
        isPresented: .constant(true)
    )
} 