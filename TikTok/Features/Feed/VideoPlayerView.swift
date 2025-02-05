import SwiftUI
import AVKit
import FirebaseStorage

struct VideoPlayerView: View {
    let video: Video
    @StateObject private var viewModel: VideoPlayerViewModel
    @State private var isMuted = true  // Default to muted
    
    init(video: Video) {
        self.video = video
        _viewModel = StateObject(wrappedValue: VideoPlayerViewModel(video: video))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
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
                            player.isMuted = isMuted  // Set initial mute state
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
                
                // Mute button overlay
                VStack {
                    HStack {
                        Button {
                            isMuted.toggle()
                            viewModel.player?.isMuted = isMuted
                        } label: {
                            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(.black.opacity(0.3))
                                .clipShape(Circle())
                        }
                        .padding(.leading, 16)
                        .padding(.top, 50)
                        
                        Spacer()
                    }
                    Spacer()
                }
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
        setupNotifications()
        Task {
            await setupPlayer()
        }
    }
    
    private func setupNotifications() {
        // Listen for stop notifications
        NotificationCenter.default.addObserver(
            forName: .stopOtherVideos,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                if let otherPlayer = notification.object as? AVPlayer,
                   otherPlayer !== self?.player {
                    self?.player?.pause()
                }
            }
        }
    }
    
    private func setupPlayer() async {
        // Convert gs:// URL to a Firebase Storage reference
        let gsURL = video.videoUrl
        guard gsURL.hasPrefix("gs://") else {
            print("Invalid video URL format: \(gsURL)")
            return
        }
        
        do {
            let storageRef = Storage.storage().reference(forURL: gsURL)
            let downloadURL = try await storageRef.downloadURL()
            
            let urlKey = NSString(string: downloadURL.absoluteString)
            if let cachedAsset = Self.assetCache.object(forKey: urlKey) {
                configurePlayer(with: cachedAsset)
                return
            }
            
            let asset = AVURLAsset(url: downloadURL)
            
            // Load essential properties
            try await asset.loadTracks(withMediaType: .video)
            _ = try await asset.load(.duration)
            
            Self.assetCache.setObject(asset, forKey: urlKey)
            configurePlayer(with: asset)
        } catch {
            print("Failed to setup player: \(error.localizedDescription)")
        }
    }
    
    private func configurePlayer(with asset: AVURLAsset) {
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        
        // Set up looping
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.player?.seek(to: .zero)
                self?.player?.play()
            }
        }
    }
    
    static func prefetchVideo(url: String) {
        guard url.hasPrefix("gs://") else { return }
        
        Task {
            do {
                let storageRef = Storage.storage().reference(forURL: url)
                let downloadURL = try await storageRef.downloadURL()
                let urlKey = NSString(string: downloadURL.absoluteString)
                
                guard assetCache.object(forKey: urlKey) == nil else { return }
                
                let asset = AVURLAsset(url: downloadURL)
                try await asset.loadTracks(withMediaType: .video)
                _ = try await asset.load(.duration)
                
                assetCache.setObject(asset, forKey: urlKey)
            } catch {
                print("Failed to prefetch video: \(error.localizedDescription)")
            }
        }
    }
}

// Add notification name
extension Notification.Name {
    static let stopOtherVideos = Notification.Name("stopOtherVideos")
} 