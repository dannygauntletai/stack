import SwiftUI
import AVKit
import FirebaseStorage
import Combine
import UIKit

struct VideoPlayerView: View {
    let video: Video
    @StateObject private var viewModel: VideoPlayerViewModel
    @ObservedObject private var stateManager = VideoStateManager.shared
    
    init(video: Video) {
        self.video = video
        _viewModel = StateObject(wrappedValue: VideoPlayerViewModel(video: video))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ZStack {
                    VideoPlayer(player: viewModel.player)
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.height,
                            alignment: .center
                        )
                        .background(Color.black)
                        .onAppear {
                            viewModel.player.isMuted = stateManager.isMuted
                            NotificationCenter.default.post(name: .stopOtherVideos, object: viewModel.player)
                            viewModel.player.play()
                        }
                        .onDisappear {
                            viewModel.player.pause()
                        }
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    } else if viewModel.isBuffering {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    }
                }
                
                // Mute button overlay
                VStack {
                    HStack {
                        Button {
                            stateManager.isMuted.toggle()
                            viewModel.player.isMuted = stateManager.isMuted
                        } label: {
                            Image(systemName: stateManager.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(.black.opacity(0.3))
                                .clipShape(Circle())
                        }
                        .padding(.leading, 16)
                        .padding(.top, geometry.safeAreaInsets.top + 16)
                        
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
    @Published private(set) var player: AVPlayer
    @Published var error: Error?
    @Published private(set) var isLoading = true
    @Published private(set) var isBuffering = false
    
    private let video: Video
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    
    // Shared player instance
    private static let sharedPlayer: AVPlayer = {
        let player = AVPlayer()
        player.automaticallyWaitsToMinimizeStalling = false
        return player
    }()
    
    // Cache with size limit of 500MB for better performance and replay
    private static let assetCache: NSCache<NSString, AVURLAsset> = {
        let cache = NSCache<NSString, AVURLAsset>()
        cache.totalCostLimit = 500 * 1024 * 1024 // 500MB
        cache.countLimit = 20 // Cache up to 20 videos
        return cache
    }()
    
    // URL cache for faster video loading
    private static let urlCache: NSCache<NSString, NSURL> = {
        let cache = NSCache<NSString, NSURL>()
        cache.countLimit = 100 // Cache up to 100 URLs
        return cache
    }()
    
    init(video: Video) {
        self.video = video
        self.player = Self.sharedPlayer
        
        setupNotifications()
        
        // Setup player
        Task {
            await setupPlayer()
        }
        
        // Setup memory warning observer
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.handleMemoryWarning()
            }
            .store(in: &cancellables)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        cancellables.removeAll()
    }
    
    private func setupNotifications() {
        // Listen for stop notifications
        NotificationCenter.default.addObserver(
            forName: .stopOtherVideos,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let otherPlayer = notification.object as? AVPlayer,
                   otherPlayer !== self.player {
                    self.player.pause()
                }
            }
        }
    }
    
    private func setupPlayer() async {
        isLoading = true
        let gsURL = video.videoUrl
        guard gsURL.hasPrefix("gs://") else {
            self.error = NSError(domain: "VideoPlayer", code: -1, 
                userInfo: [NSLocalizedDescriptionKey: "Invalid video URL format: \(gsURL)"])
            isLoading = false
            return
        }
        
        do {
            let storageRef = Storage.storage().reference(forURL: gsURL)
            
            // Check URL cache first
            let urlKey = NSString(string: gsURL)
            if let cachedURL = Self.urlCache.object(forKey: urlKey) as URL? {
                await configurePlayerWithURL(cachedURL)
                return
            }
            
            // Get download URL
            let downloadURL = try await storageRef.downloadURL()
            Self.urlCache.setObject(downloadURL as NSURL, forKey: urlKey)
            
            // Check asset cache
            let assetKey = NSString(string: downloadURL.absoluteString)
            if let cachedAsset = Self.assetCache.object(forKey: assetKey) {
                configurePlayer(with: cachedAsset)
                return
            }
            
            // Configure player with URL first for faster initial playback
            await configurePlayerWithURL(downloadURL)
            
            // Then load asset in background for better quality
            Task.detached { [downloadURL, assetKey] in
                let asset = AVURLAsset(url: downloadURL, options: [
                    AVURLAssetPreferPreciseDurationAndTimingKey: true
                ])
                
                do {
                    // Load essential properties
                    try await asset.loadTracks(withMediaType: .video)
                    let duration = try await asset.load(.duration)
                    
                    // Set cache cost based on duration
                    let costInBytes = Int(duration.seconds) * 100_000
                    await MainActor.run {
                        Self.assetCache.setObject(asset, forKey: assetKey, cost: costInBytes)
                        self.configurePlayer(with: asset)
                    }
                } catch {
                    print("Background asset loading failed: \(error)")
                }
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    private func configurePlayer(with asset: AVURLAsset) {
        cleanupCurrentPlayer()
        
        let playerItem = AVPlayerItem(asset: asset)
        self.playerItem = playerItem
        configurePlayerItem(playerItem)
        
        player.replaceCurrentItem(with: playerItem)
        configureTimeObserver(for: player)
        isLoading = false
    }
    
    private func configurePlayerWithURL(_ url: URL) async {
        await MainActor.run {
            cleanupCurrentPlayer()
            
            let playerItem = AVPlayerItem(url: url)
            playerItem.preferredForwardBufferDuration = 10.0 // Buffer 10 seconds ahead for better replay
            self.playerItem = playerItem
            configurePlayerItem(playerItem)
            
            player.replaceCurrentItem(with: playerItem)
            configureTimeObserver(for: player)
            isLoading = false
            
            // Preload the video data
            playerItem.preferredPeakBitRate = 2_500_000 // 2.5 Mbps for good quality
            playerItem.automaticallyPreservesTimeOffsetFromLive = false
        }
    }
    
    private func configurePlayerItem(_ playerItem: AVPlayerItem) {
        // Optimize for playback speed and replay performance
        playerItem.preferredForwardBufferDuration = 10.0 // Buffer 10 seconds ahead
        
        // Set up looping
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.player.seek(to: .zero)
                self.player.play()
            }
        }
        
        // Monitor buffering state
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isBuffering = true
            }
        }
        
        playerItem.publisher(for: \.isPlaybackBufferEmpty)
            .receive(on: RunLoop.main)
            .sink { [weak self] isEmpty in
                guard let self = self else { return }
                self.isBuffering = isEmpty
            }
            .store(in: &cancellables)
        
        playerItem.publisher(for: \.isPlaybackLikelyToKeepUp)
            .receive(on: RunLoop.main)
            .sink { [weak self] isLikely in
                guard let self = self else { return }
                if isLikely {
                    self.isBuffering = false
                    self.player.play()
                }
            }
            .store(in: &cancellables)
    }
    
    private func configureTimeObserver(for player: AVPlayer) {
        // Add time observer to monitor playback progress
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            
            if let currentItem = self.player.currentItem {
                // Check if we need to preload the next chunk
                let duration = currentItem.duration.seconds
                let currentTime = currentItem.currentTime().seconds
                let timeRemaining = duration - currentTime
                
                if timeRemaining < 1.0 && !self.isBuffering {
                    self.player.preroll(atRate: 1.0)
                }
            }
        }
    }
    
    private func cleanupCurrentPlayer() {
        if let timeObserver = timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        player.pause()
        // Don't clear the player item if we're just pausing temporarily
        // This helps with replay performance
        if isLoading {
            player.replaceCurrentItem(with: nil)
            playerItem = nil
        }
    }
    
    private func handleMemoryWarning() {
        // Only remove older cached assets, keeping the most recent ones
        // This helps with replay performance while still managing memory
        if Self.assetCache.countLimit > 5 {
            Self.assetCache.countLimit = 5
        }
        
        // Only clear player item if we're under severe memory pressure
        if UIApplication.shared.applicationState == .background {
            player.replaceCurrentItem(with: nil)
            playerItem = nil
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