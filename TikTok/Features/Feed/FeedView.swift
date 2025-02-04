import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var currentIndex = 0
    @State private var currentInteraction = VideoInteraction(likes: 0, comments: 0, isLiked: false)
    @State private var showComments = false
    
    var body: some View {
        ZStack(alignment: .trailing) {
            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.error {
                Text("Error: \(error.localizedDescription)")
            } else if viewModel.videos.isEmpty {
                Text("No videos available")
            } else {
                GeometryReader { geometry in
                    TabView(selection: $currentIndex) {
                        ForEach(Array(viewModel.videos.enumerated()), id: \.element.id) { index, video in
                            ZStack {
                                VideoPlayerView(video: video)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                            }
                            .rotationEffect(.degrees(-90))
                            .frame(width: geometry.size.height, height: geometry.size.width)
                            .tag(index)
                        }
                    }
                    .frame(width: geometry.size.height, height: geometry.size.width)
                    .rotationEffect(.degrees(90), anchor: .topLeading)
                    .offset(x: geometry.size.width)
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                }
                
                // Overlay
                if !viewModel.videos.isEmpty {
                    VideoOverlayView(
                        video: viewModel.videos[currentIndex],
                        interaction: $currentInteraction,
                        onCommentsPress: { showComments = true }
                    )
                    .frame(width: 80)
                    .padding(.trailing, 8)
                    .padding(.bottom, 140)
                }
            }
        }
        .ignoresSafeArea()
        .statusBar(hidden: true)
        .background(Color.black)
        .sheet(isPresented: $showComments) {
            CommentsSheet()
                .presentationDetents([.medium, .large])
        }
        .onChange(of: currentIndex) { _, newValue in
            // Reset interaction for new video
            currentInteraction = VideoInteraction(
                likes: viewModel.videos[newValue].likes,
                comments: viewModel.videos[newValue].comments,
                isLiked: false
            )
        }
        .task {
            await viewModel.fetchVideos()
        }
    }
}

// Safe array access extension
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
} 