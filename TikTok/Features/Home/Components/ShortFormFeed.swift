import SwiftUI
import Combine

struct ShortFormFeed: View {
    @EnvironmentObject var viewModel: ShortFormFeedViewModel
    @State private var currentIndex = 0
    @State private var viewableRange: Range<Int> = 0..<1
    
    // Keep existing initialVideo parameter
    let initialVideo: Video?
    
    var videos: [Video] {
        if let initialVideo = initialVideo {
            return [initialVideo]
        }
        return viewModel.videos
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            switch viewModel.loadingState {
            case .loading:
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            
            case .empty:
                VStack(spacing: 12) {
                    Text("No videos available")
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                    Text("Tap to refresh")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.7))
                }
                .onTapGesture {
                    viewModel.loadVideos()
                }
                
            case .error(let error):
                VStack(spacing: 12) {
                    Text("Failed to Load Videos")
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                    Text("Tap to retry")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.7))
                }
                .onTapGesture {
                    viewModel.loadVideos()
                }
                
            case .idle, .loaded:
                if !videos.isEmpty {
                    // Video feed
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(videos.indices, id: \.self) { index in
                                if let url = URL(string: videos[index].videoUrl) {
                                    GeometryReader { geometry in
                                        let minY = geometry.frame(in: .global).minY
                                        let height = UIScreen.main.bounds.height
                                        let visibility = calculateVisibility(minY: minY, height: height)
                                        
                                        ShortFormVideoPlayer(
                                            videoURL: url,
                                            visibility: visibility
                                        )
                                        .onChange(of: visibility) { oldValue, newValue in
                                            if newValue.isFullyVisible {
                                                // Safely update current index
                                                if index < videos.count {
                                                    currentIndex = index
                                                    viewableRange = max(0, index - 1)..<min(videos.count, index + 2)
                                                    
                                                    // Load more videos when near the end
                                                    if index >= videos.count - 2 {
                                                        viewModel.loadMoreVideos()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .frame(height: UIScreen.main.bounds.height)
                                }
                            }
                        }
                    }
                    .scrollTargetBehavior(.paging)
                    .ignoresSafeArea()
                    
                    // Fixed overlay that stays on top
                    if !videos.isEmpty && currentIndex < videos.count {
                        HomeVideoOverlay(video: videos[currentIndex])
                            .allowsHitTesting(true)
                    }
                }
            }
        }
        .onAppear {
            if initialVideo == nil {
                viewModel.loadVideos()
            }
        }
    }
    
    private func calculateVisibility(minY: CGFloat, height: CGFloat) -> VideoVisibility {
        let threshold: CGFloat = 0.5 // 50% visibility threshold
        let visibleHeight = height - abs(minY)
        let visibilityPercentage = visibleHeight / height
        
        return VideoVisibility(
            isFullyVisible: abs(minY) < height * 0.5, // More lenient threshold
            isPartiallyVisible: visibilityPercentage >= threshold,
            visibilityPercentage: max(0, min(1, visibilityPercentage))
        )
    }
}

// Video visibility state
struct VideoVisibility: Equatable {
    let isFullyVisible: Bool
    let isPartiallyVisible: Bool
    let visibilityPercentage: CGFloat
}

#Preview {
    ShortFormFeed(initialVideo: nil)
        .preferredColorScheme(.dark)
} 