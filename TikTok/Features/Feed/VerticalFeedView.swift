import SwiftUI
import UIKit
import AVKit
import AVFoundation
import Combine
import FirebaseFirestore
import FirebaseStorage

struct VerticalFeedView: UIViewControllerRepresentable {
    let videos: [Video]
    let currentIndex: Binding<Int>
    let viewModel: FeedViewModel
    let interaction: Binding<VideoInteraction>
    let onCommentsPress: () -> Void
    
    func makeUIViewController(context: Context) -> UICollectionViewController {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.itemSize = UIScreen.main.bounds.size
        
        let controller = FeedCollectionViewController(
            collectionViewLayout: layout,
            videos: videos,
            currentIndex: currentIndex,
            viewModel: viewModel,
            interaction: interaction,
            onCommentsPress: onCommentsPress
        )
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UICollectionViewController, context: Context) {
        if let controller = uiViewController as? FeedCollectionViewController {
            controller.updateVideos(videos)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: VerticalFeedView
        
        init(_ parent: VerticalFeedView) {
            self.parent = parent
        }
    }
}

class FeedCollectionViewController: UICollectionViewController {
    private var videos: [Video]
    private let currentIndex: Binding<Int>
    private let viewModel: FeedViewModel
    private let interaction: Binding<VideoInteraction>
    private let onCommentsPress: () -> Void
    private var currentCell: VideoPlayerCell?
    private var overlayHostingController: UIHostingController<VideoOverlayView>?
    
    init(
        collectionViewLayout: UICollectionViewLayout,
        videos: [Video],
        currentIndex: Binding<Int>,
        viewModel: FeedViewModel,
        interaction: Binding<VideoInteraction>,
        onCommentsPress: @escaping () -> Void
    ) {
        self.videos = videos
        self.currentIndex = currentIndex
        self.viewModel = viewModel
        self.interaction = interaction
        self.onCommentsPress = onCommentsPress
        super.init(collectionViewLayout: collectionViewLayout)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupOverlay()
    }
    
    private func setupCollectionView() {
        collectionView.isPagingEnabled = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.backgroundColor = .black
        collectionView.register(VideoPlayerCell.self, forCellWithReuseIdentifier: "VideoCell")
        
        // Fix scrolling behavior
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.verticalScrollIndicatorInsets = .zero
        collectionView.contentInset = .zero
        
        // Prevent bounce/scroll at the end
        collectionView.bounces = false
        collectionView.alwaysBounceVertical = false
    }
    
    private func setupOverlay() {
        guard let video = videos.first else { return }
        
        let overlay = VideoOverlayView(
            video: video,
            viewModel: viewModel,
            interaction: interaction,
            onCommentsPress: onCommentsPress
        )
        
        overlayHostingController = UIHostingController(rootView: overlay)
        overlayHostingController?.view.backgroundColor = .clear
        
        if let overlayView = overlayHostingController?.view {
            view.addSubview(overlayView)
            overlayView.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0),
                overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -140),
                overlayView.widthAnchor.constraint(equalToConstant: 80),
                overlayView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.35)
            ])
        }
    }
    
    func updateVideos(_ newVideos: [Video]) {
        videos = newVideos
        collectionView.reloadData()
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return videos.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "VideoCell",
            for: indexPath
        ) as? VideoPlayerCell else {
            return UICollectionViewCell()
        }
        
        let video = videos[indexPath.item]
        cell.configure(with: video)
        
        return cell
    }
    
    override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let page = Int(scrollView.contentOffset.y / scrollView.bounds.height)
        currentIndex.wrappedValue = page
        
        // Update overlay with current video
        if let video = videos[safe: page] {
            overlayHostingController?.rootView = VideoOverlayView(
                video: video,
                viewModel: viewModel,
                interaction: interaction,
                onCommentsPress: onCommentsPress
            )
        }
        
        // Update current cell
        if let cell = collectionView.visibleCells.first as? VideoPlayerCell {
            currentCell?.pause()
            currentCell = cell
            cell.play()
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let videoCell = cell as? VideoPlayerCell else { return }
        if currentCell == nil {
            currentCell = videoCell
            videoCell.play()
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let videoCell = cell as? VideoPlayerCell else { return }
        videoCell.pause()
        if currentCell == videoCell {
            currentCell = nil
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Ensure collection view layout matches screen bounds exactly
        if let layout = collectionViewLayout as? UICollectionViewFlowLayout {
            layout.itemSize = view.bounds.size
            layout.minimumInteritemSpacing = 0
            layout.minimumLineSpacing = 0
            layout.sectionInset = .zero
        }
    }
}

// Track active downloads to prevent duplicates
class VideoDownloadManager {
    static let shared = VideoDownloadManager()
    private var activeDownloads: Set<String> = []
    private let queue = DispatchQueue(label: "com.tiktok.videodownload")
    
    func isDownloading(_ videoId: String) -> Bool {
        queue.sync { activeDownloads.contains(videoId) }
    }
    
    func startDownload(_ videoId: String) -> Bool {
        queue.sync {
            guard !activeDownloads.contains(videoId) else { return false }
            activeDownloads.insert(videoId)
            return true
        }
    }
    
    func finishDownload(_ videoId: String) {
        queue.sync { activeDownloads.remove(videoId) }
    }
}

class VideoPlayerCell: UICollectionViewCell {
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var cancellables = Set<AnyCancellable>()
    private var currentVideoUrl: String?
    private var setupTask: Task<Void, Never>?
    private var playerStatusObserver: NSKeyValueObservation?
    
    func configure(with video: Video) {
        print("[VideoPlayer] Configuring cell for video: \(video.id)")
        
        // Cancel any existing setup task
        setupTask?.cancel()
        
        // If we're already configured for this video URL, just update play state
        if currentVideoUrl == video.videoUrl {
            print("[VideoPlayer] Already configured for this URL")
            if VideoStateManager.shared.currentVideo?.id == video.id {
                // Only attempt to play if player exists
                if player != nil {
                    print("[VideoPlayer] Playing existing video")
                    play()
                } else {
                    print("[VideoPlayer] Player is nil, setting up new player")
                    setupPlayer(with: video)
                }
            }
            return
        }
        
        // Clean up existing player
        cleanup()
        
        currentVideoUrl = video.videoUrl
        setupPlayer(with: video)
    }
    
    private func setupPlayer(with video: Video) {
        print("[VideoPlayer] Setting up player for video URL: \(video.videoUrl) (ID: \(video.id))")
        guard video.videoUrl.hasPrefix("gs://") else {
            print("[VideoPlayer] Invalid video URL format: \(video.videoUrl)")
            return
        }
        
        // Clean up any existing observation
        playerStatusObserver?.invalidate()
        playerStatusObserver = nil
        
        setupTask = Task {
            do {
                let storage = Storage.storage()
                let storageRef = storage.reference(forURL: video.videoUrl)
                
                // Check if file already exists
                let localURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("\(video.id).mp4")
                
                print("[VideoPlayer] Checking file at: \(localURL.path)")
                if !FileManager.default.fileExists(atPath: localURL.path) {
                    print("[VideoPlayer] File does not exist, starting download")
                    // Check if already downloading
                    guard VideoDownloadManager.shared.startDownload(video.id) else {
                        print("[VideoPlayer] Download already in progress for \(video.id)")
                        throw NSError(domain: "VideoPlayerError", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "Download already in progress"])
                    }
                    
                    defer { VideoDownloadManager.shared.finishDownload(video.id) }
                    
                    print("[VideoPlayer] Starting download for \(video.id)")
                    
                    // Download data first
                    let data = try await storageRef.data(maxSize: 50 * 1024 * 1024) // 50MB limit
                    print("[VideoPlayer] Downloaded \(data.count) bytes")
                    
                    // Write to file
                    try data.write(to: localURL)
                    print("[VideoPlayer] Successfully wrote file to: \(localURL.path)")
                } else {
                    print("[VideoPlayer] File already exists at: \(localURL.path)")
                }
                
                // Verify file exists and has content
                guard FileManager.default.fileExists(atPath: localURL.path),
                      let attributes = try? FileManager.default.attributesOfItem(atPath: localURL.path),
                      let fileSize = attributes[.size] as? UInt64,
                      fileSize > 0 else {
                    throw NSError(domain: "VideoPlayerError", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Downloaded file is invalid or empty"])
                }
                
                print("[VideoPlayer] Download complete (\(fileSize) bytes), creating player")
                
                // Try to read first few bytes to verify it's a valid MP4
                guard let fileHandle = try? FileHandle(forReadingFrom: localURL),
                      let header = try? fileHandle.read(upToCount: 8),
                      header.count == 8 else {
                    throw NSError(domain: "VideoPlayerError", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "File is not a valid video"])
                }
                
                // Convert header bytes to string for debugging
                let headerString = header.map { String(format: "%02X", $0) }.joined()
                print("[VideoPlayer] File header: \(headerString)")
                
                if Task.isCancelled { return }
                
                // Create player without audio first
                let asset = AVURLAsset(url: localURL)
                
                // Get video track only
                let videoTracks = try await asset.loadTracks(withMediaType: .video)
                guard let videoTrack = videoTracks.first else {
                    throw NSError(domain: "VideoPlayerError", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "No video track found"])
                }
                
                print("[VideoPlayer] Found video track, creating composition")
                
                // Create composition with just video
                let composition = AVMutableComposition()
                let compositionTrack = composition.addMutableTrack(
                    withMediaType: .video,
                    preferredTrackID: kCMPersistentTrackID_Invalid)
                
                // Add video track to composition
                try compositionTrack?.insertTimeRange(
                    CMTimeRange(start: .zero, duration: try await asset.load(.duration)),
                    of: videoTrack,
                    at: .zero)
                
                // Create export session with video-only composition
                guard let exportSession = AVAssetExportSession(asset: composition,
                                                              presetName: AVAssetExportPresetHighestQuality) else {
                    throw NSError(domain: "VideoPlayerError", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Cannot create export session"])
                }
                
                let transcodedURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("\(video.id)_video_only.mp4")
                
                print("[VideoPlayer] Transcoding video-only to: \(transcodedURL.path)")
                try? FileManager.default.removeItem(at: transcodedURL)
                
                exportSession.outputURL = transcodedURL
                exportSession.outputFileType = .mp4
                
                // Export the video
                print("[VideoPlayer] Starting export with preset: \(exportSession.presetName ?? "unknown")")
                await exportSession.export()
                
                print("[VideoPlayer] Export status: \(exportSession.status.rawValue)")
                if let error = exportSession.error {
                    print("[VideoPlayer] Export failed: \(error)")
                    throw error
                }
                
                // Verify transcoded file exists and has content
                guard FileManager.default.fileExists(atPath: transcodedURL.path),
                      let attributes = try? FileManager.default.attributesOfItem(atPath: transcodedURL.path),
                      let fileSize = attributes[.size] as? UInt64,
                      fileSize > 0 else {
                    throw NSError(domain: "VideoPlayerError", code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Transcoded file is invalid or empty"])
                }
                
                print("[VideoPlayer] Transcoding complete, file size: \(fileSize) bytes")
                
                // Create player from transcoded file
                let playerItem = AVPlayerItem(url: transcodedURL)
                playerItem.preferredForwardBufferDuration = 2.0
                
                print("[VideoPlayer] Creating player with transcoded URL: \(transcodedURL.path)")
                
                // Add item status observation before creating player
                var itemObservation: NSKeyValueObservation? = nil
                itemObservation = playerItem.observe(\.status) { [weak self] item, _ in
                    guard let self = self else { return }
                    
                    switch item.status {
                    case .readyToPlay:
                        print("[VideoPlayer] Item is ready to play")
                        if VideoStateManager.shared.currentVideo?.id == video.id {
                            self.play()
                        }
                    case .failed:
                        print("[VideoPlayer] Item failed: \(String(describing: item.error))")
                    case .unknown:
                        print("[VideoPlayer] Item status unknown")
                    @unknown default:
                        break
                    }
                    
                    // Clean up observation after status is determined
                    if item.status != .unknown {
                        itemObservation?.invalidate()
                        itemObservation = nil
                    }
                }
                
                await MainActor.run {
                    guard !Task.isCancelled else {
                        itemObservation?.invalidate()
                        return
                    }
                    
                    print("[VideoPlayer] Creating player with transcoded URL: \(transcodedURL.path)")
                    let player = AVPlayer(playerItem: playerItem)
                    
                    // Configure player for better streaming
                    player.automaticallyWaitsToMinimizeStalling = true
                    
                    // Add status observer
                    playerStatusObserver = playerItem.observe(\.status) { [weak self] item, _ in
                        switch item.status {
                        case .failed:
                            print("[VideoPlayer] Item failed: \(String(describing: item.error))")
                            if let error = item.error {
                                self?.handlePlaybackError(error, for: video)
                            }
                        case .readyToPlay:
                            print("[VideoPlayer] Item is ready to play")
                            if VideoStateManager.shared.currentVideo?.id == video.id {
                                self?.play()
                            }
                        default:
                            break
                        }
                    }
                    
                    // Set up player item notifications
                    NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime,
                                                        object: playerItem,
                                                        queue: .main) { [weak self] notification in
                        if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                            print("[VideoPlayer] Playback failed with error: \(error)")
                            // Attempt to recover
                            self?.handlePlaybackError(error, for: video)
                        }
                    }
                    
                    // Configure audio session
                    try? AVAudioSession.sharedInstance().setCategory(.playback)
                    try? AVAudioSession.sharedInstance().setActive(true)
                    
                    self.player = player
                    
                    let playerLayer = AVPlayerLayer(player: player)
                    self.playerLayer = playerLayer
                    playerLayer.videoGravity = .resizeAspectFill
                    playerLayer.frame = contentView.bounds
                    print("[VideoPlayer] Player layer frame: \(playerLayer.frame)")
                    print("[VideoPlayer] Content view bounds: \(contentView.bounds)")
                    contentView.layer.addSublayer(playerLayer)
                    
                    // Set initial state
                    player.isMuted = VideoStateManager.shared.isMuted
                    
                    // Observe player status using modern KVO
                    self.playerStatusObserver = player.observe(\.timeControlStatus) { [weak self] player, _ in
                        guard let self = self else { return }
                        
                        switch player.timeControlStatus {
                        case .playing:
                            print("[VideoPlayer] Player is playing (ID: \(video.id))")
                        case .paused:
                            print("[VideoPlayer] Player is paused (ID: \(video.id))")
                        case .waitingToPlayAtSpecifiedRate:
                            print("[VideoPlayer] Player is waiting to play (ID: \(video.id))")
                        @unknown default:
                            break
                        }
                    }
                }
            } catch {
                print("[VideoPlayer] Failed to load video: \(error.localizedDescription)")
            }
        }
    }
    
    private func observeVideoState() {
        VideoStateManager.shared.$isMuted
            .sink { [weak self] isMuted in
                self?.player?.isMuted = isMuted
            }
            .store(in: &cancellables)
            
        VideoStateManager.shared.$isPlaying
            .sink { [weak self] isPlaying in
                if isPlaying {
                    self?.play()
                } else {
                    self?.pause()
                }
            }
            .store(in: &cancellables)
    }
    
    private func cleanup() {
        cancellables.removeAll()
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        playerStatusObserver?.invalidate()
        playerStatusObserver = nil
        player = nil
        playerLayer = nil
        
        // Clean up temporary file
        if let videoUrl = currentVideoUrl,
           let videoId = videoUrl.components(separatedBy: "/").last?.replacingOccurrences(of: ".mp4", with: "") {
            let tmpURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(videoId).mp4")
            try? FileManager.default.removeItem(at: tmpURL)
        }
        
        currentVideoUrl = nil
        setupTask?.cancel()
        setupTask = nil
        
        // Remove any observers
        NotificationCenter.default.removeObserver(self)
    }
    
    private func handlePlaybackError(_ error: Error, for video: Video) {
        print("[VideoPlayer] Handling playback error for video \(video.id): \(error)")
        
        // Clean up current player
        cleanup()
        
        // Attempt to recreate player with different configuration
        Task {
            do {
                // Wait a moment before retrying
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                // Only retry if this is still the current video
                if VideoStateManager.shared.currentVideo?.id == video.id {
                    print("[VideoPlayer] Retrying playback setup for video \(video.id)")
                    setupPlayer(with: video)
                }
            } catch {
                print("[VideoPlayer] Error during retry: \(error)")
            }
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        cleanup()
    }
    
    func play() {
        guard let player = player else {
            print("[VideoPlayer] Cannot play - player is nil")
            return
        }
        
        // Only play if this cell's video matches the current video
        if let currentVideo = VideoStateManager.shared.currentVideo,
           currentVideo.videoUrl == currentVideoUrl {
            print("[VideoPlayer] Playing video: \(currentVideo.id)")
            player.play()
        } else {
            print("[VideoPlayer] Not playing - video mismatch")
        }
    }
    
    func pause() {
        guard let player = player else { return }
        print("[VideoPlayer] Pausing video")
        player.pause()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if let playerLayer = playerLayer {
            playerLayer.frame = contentView.bounds
            print("[VideoPlayer] Updated player layer frame: \(playerLayer.frame)")
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItem.Status
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItem.Status(rawValue: statusNumber.intValue) ?? .unknown
            } else {
                status = .unknown
            }
            
            switch status {
            case .readyToPlay:
                print("[VideoPlayer] Player item is ready to play")
                if let playerItem = object as? AVPlayerItem,
                   playerItem == player?.currentItem,
                   let video = VideoStateManager.shared.currentVideo,
                   let currentVideoUrl = currentVideoUrl,
                   video.videoUrl == currentVideoUrl {
                    play()
                }
            case .failed:
                if let error = player?.currentItem?.error {
                    print("[VideoPlayer] Player item failed with error: \(error)")
                    // Try to recover by recreating the player
                    if let video = VideoStateManager.shared.currentVideo,
                       let currentVideoUrl = currentVideoUrl,
                       video.videoUrl == currentVideoUrl {
                        cleanup()
                        setupPlayer(with: video)
                    }
                }
            case .unknown:
                print("[VideoPlayer] Player item status is unknown")
            @unknown default:
                break
            }
        }
    }
} 