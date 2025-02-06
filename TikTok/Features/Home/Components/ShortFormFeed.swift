import SwiftUI

struct ShortFormFeed: View {
    @State private var currentIndex = 0
    @State private var viewableRange: Range<Int> = 0..<1
    
    // Test video URLs
    let testVideos = Array(repeating: 
        "https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/1080/Big_Buck_Bunny_1080_10s_30MB.mp4", 
        count: 5)
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(testVideos.indices, id: \.self) { index in
                    if let url = URL(string: testVideos[index]) {
                        ShortFormVideoPlayer(
                            videoURL: url,
                            isCurrentlyVisible: viewableRange.contains(index)
                        )
                        .frame(height: UIScreen.main.bounds.height)
                        .id(index)
                        .onAppear {
                            currentIndex = index
                            viewableRange = max(0, index - 1)..<min(testVideos.count, index + 2)
                        }
                    }
                }
            }
        }
        .scrollTargetBehavior(.paging)
        .ignoresSafeArea()
    }
}

#Preview {
    ShortFormFeed()
        .preferredColorScheme(.dark)
} 