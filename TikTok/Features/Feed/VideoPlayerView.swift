import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let video: Video
    @StateObject private var viewModel: VideoPlayerViewModel
    
    init(video: Video) {
        self.video = video
        _viewModel = StateObject(wrappedValue: VideoPlayerViewModel(video: video))
    }
    
    var body: some View {
        GeometryReader { geometry in
            if let player = viewModel.player {
                VideoPlayer(player: player)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .rotationEffect(.degrees(90))
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                        player.seek(to: .zero)
                    }
            } else {
                Color.black
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
}

@MainActor
class VideoPlayerViewModel: ObservableObject {
    @Published private(set) var player: AVPlayer?
    private let video: Video
    private var playerItem: AVPlayerItem?
    
    init(video: Video) {
        self.video = video
        Task {
            await setupPlayer()
        }
    }
    
    private func setupPlayer() async {
        guard let url = URL(string: "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4") else { return }
        
        let asset = AVURLAsset(url: url)
        do {
            let _ = try await asset.load(.tracks, .duration)
            playerItem = AVPlayerItem(asset: asset)
            player = AVPlayer(playerItem: playerItem)
            
            // Set up looping
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerItem,
                queue: nil) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.player?.seek(to: .zero)
                        self?.player?.play()
                    }
                }
        } catch {
            print("Failed to load asset:", error)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
} 