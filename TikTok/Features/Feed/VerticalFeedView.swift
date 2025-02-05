import SwiftUI
import UIKit
import AVKit
import AVFoundation

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

class VideoPlayerCell: UICollectionViewCell {
    private var playerLayer: AVPlayerLayer?
    private var player: AVPlayer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with video: Video) {
        // Clean up existing player if any
        playerLayer?.removeFromSuperlayer()
        player?.pause()
        
        guard let url = URL(string: video.videoUrl) else { return }
        
        player = AVPlayer(url: url)
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspect
        playerLayer?.frame = contentView.bounds
        
        if let playerLayer = playerLayer {
            contentView.layer.addSublayer(playerLayer)
        }
    }
    
    func play() {
        player?.play()
    }
    
    func pause() {
        player?.pause()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = contentView.bounds
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        player = nil
        playerLayer = nil
    }
} 