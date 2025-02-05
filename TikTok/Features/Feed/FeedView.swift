import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var currentIndex = 0
    @State private var currentInteraction = VideoInteraction(likes: 0, comments: 0, isLiked: false)
    @State private var showComments = false
    let initialVideo: Video?
    var isDeepLinked: Bool = false
    var onBack: (() -> Void)? = nil
    @State private var dragOffset = CGSize.zero
    @Environment(\.dismiss) private var dismiss
    
    init(
        initialVideo: Video? = nil,
        isDeepLinked: Bool = false,
        onBack: (() -> Void)? = nil
    ) {
        self.initialVideo = initialVideo
        self.isDeepLinked = isDeepLinked
        self.onBack = onBack
        _currentIndex = State(initialValue: 0)
    }
    
    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.error {
                Text("Error: \(error.localizedDescription)")
            } else if viewModel.videos.isEmpty {
                Text("No videos available")
            } else {
                VerticalFeedView(
                    videos: viewModel.videos,
                    currentIndex: $currentIndex,
                    viewModel: viewModel,
                    interaction: $currentInteraction,
                    onCommentsPress: { showComments = true }
                )
                .ignoresSafeArea()
                
                if isDeepLinked {
                    VStack {
                        HStack {
                            Button {
                                onBack?()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(16)
                            }
                            Spacer()
                        }
                        .padding(.top, 44)
                        Spacer()
                    }
                }
            }
        }
        .sheet(isPresented: $showComments) {
            CommentsSheet(video: viewModel.videos[currentIndex]) {
                if let index = viewModel.videos.firstIndex(where: { $0.id == viewModel.videos[currentIndex].id }) {
                    viewModel.videos[index].comments += 1
                    currentInteraction.comments = viewModel.videos[index].comments
                }
            }
            .presentationDetents([.medium, .large])
        }
        .onChange(of: currentIndex) { _, newValue in
            updateInteractionState(for: newValue)
        }
        .task {
            await viewModel.fetchVideos(initialVideo: initialVideo)
            if initialVideo != nil {
                updateInteractionState(for: currentIndex)
            }
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