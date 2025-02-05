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
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height,
                        alignment: .center
                    )
                    .background(Color.black)
                    .onAppear {
                        player.replaceCurrentItem(with: player.currentItem)
                        NotificationCenter.default.post(name: .stopOtherVideos, object: player)
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
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
    private static var assetCache = NSCache<NSString, AVURLAsset>()
    
    init(video: Video) {
        self.video = video
        
        // Listen for stop notifications
        NotificationCenter.default.addObserver(
            forName: .stopOtherVideos,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let otherPlayer = notification.object as? AVPlayer,
               otherPlayer !== self?.player {
                self?.player?.pause()
            }
        }
        
        Task {
            await setupPlayer()
        }
    }
    
    private func setupPlayer() async {
        guard let url = URL(string: video.videoUrl) else { return }
        
        let urlKey = NSString(string: url.absoluteString)
        if let cachedAsset = Self.assetCache.object(forKey: urlKey) {
            configurePlayer(with: cachedAsset)
            return
        }
        
        let asset = AVURLAsset(url: url)
        do {
            let _ = try await asset.load(.tracks, .duration)
            Self.assetCache.setObject(asset, forKey: urlKey)
            configurePlayer(with: asset)
        } catch {
            print("Failed to load asset:", error)
        }
    }
    
    private func configurePlayer(with asset: AVURLAsset) {
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        
        // Set up looping
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: nil
        ) { [weak self] _ in
            self?.player?.seek(to: .zero)
            self?.player?.play()
        }
    }
    
    static func prefetchVideo(url: String) {
        guard let videoURL = URL(string: url) else { return }
        let urlKey = NSString(string: videoURL.absoluteString)
        
        guard assetCache.object(forKey: urlKey) == nil else { return }
        
        let asset = AVURLAsset(url: videoURL)
        Task {
            do {
                let _ = try await asset.load(.tracks, .duration)
                assetCache.setObject(asset, forKey: urlKey)
            } catch {
                print("Failed to prefetch video:", error)
            }
        }
    }
}

// Add notification name
extension Notification.Name {
    static let stopOtherVideos = Notification.Name("stopOtherVideos")
} 