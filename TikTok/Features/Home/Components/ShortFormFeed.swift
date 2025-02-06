import SwiftUI

struct ShortFormFeed: View {
    @State private var currentIndex = 0
    @State private var viewableRange: Range<Int> = 0..<1
    
    // Test video URLs
    let testVideos = Array(repeating: 
        "https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/1080/Big_Buck_Bunny_1080_10s_30MB.mp4", 
        count: 5)
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Video feed
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(testVideos.indices, id: \.self) { index in
                        if let url = URL(string: testVideos[index]) {
                            GeometryReader { geometry in
                                let minY = geometry.frame(in: .global).minY
                                let height = UIScreen.main.bounds.height
                                let visibility = calculateVisibility(minY: minY, height: height)
                                
                                ShortFormVideoPlayer(
                                    videoURL: url,
                                    visibility: visibility
                                )
                                .onChange(of: visibility) { newVisibility in
                                    if newVisibility.isFullyVisible {
                                        currentIndex = index
                                        viewableRange = max(0, index - 1)..<min(testVideos.count, index + 2)
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
            HomeVideoOverlay(videoUrl: testVideos[currentIndex])
                .allowsHitTesting(true)
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
    ShortFormFeed()
        .preferredColorScheme(.dark)
} 