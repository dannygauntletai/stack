import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var currentIndex = 0
    
    var body: some View {
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
        .ignoresSafeArea()
        .statusBar(hidden: true)
        .background(Color.black)
        .task {
            await viewModel.fetchVideos()
        }
    }
} 