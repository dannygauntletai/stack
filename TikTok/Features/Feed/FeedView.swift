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
                        viewModel: viewModel,
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
            CommentsSheet(
                video: viewModel.videos[currentIndex]
            ) { [video = viewModel.videos[currentIndex]] in
                // Update both the interaction state and the video model
                if let index = viewModel.videos.firstIndex(where: { $0.id == video.id }) {
                    viewModel.videos[index].comments += 1
                    currentInteraction.comments = viewModel.videos[index].comments
                }
            }
            .presentationDetents([.medium, .large])
        }
        .onChange(of: currentIndex) { _, newValue in
            updateInteractionState(for: newValue)
            
            // Prefetch next video
            if newValue + 1 < viewModel.videos.count {
                let nextVideo = viewModel.videos[newValue + 1]
                VideoPlayerViewModel.prefetchVideo(url: nextVideo.videoUrl)
            }
        }
        .onAppear {
            // Ensure correct state when returning to the feed
            updateInteractionState(for: currentIndex)
        }
        .task {
            await viewModel.fetchVideos()
        }
    }
    
    private func updateInteractionState(for index: Int) {
        guard index < viewModel.videos.count else { return }
        let video = viewModel.videos[index]
        currentInteraction = VideoInteraction(
            likes: video.likes,
            comments: video.comments,
            isLiked: viewModel.likedVideoIds.contains(video.id)
        )
    }
}

// Safe array access extension
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
} 