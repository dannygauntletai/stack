import SwiftUI
import AVKit
import AVFoundation

struct ShortFormPlayer: UIViewRepresentable {
    let url: URL
    @Binding var isPlaying: Bool
    
    // Coordinator to handle player callbacks
    class Coordinator: NSObject {
        let parent: ShortFormPlayer
        var player: AVPlayer?
        var playerLayer: AVPlayerLayer?
        
        init(_ parent: ShortFormPlayer) {
            self.parent = parent
        }
        
        func cleanup() {
            player?.pause()
            player = nil
            playerLayer?.removeFromSuperlayer()
            playerLayer = nil
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black
        
        // Create player
        let player = AVPlayer(url: url)
        player.automaticallyWaitsToMinimizeStalling = true
        
        // Create layer
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = UIScreen.main.bounds
        view.layer.addSublayer(playerLayer)
        
        // Store references
        context.coordinator.player = player
        context.coordinator.playerLayer = playerLayer
        
        // Configure looping
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            if context.coordinator.parent.isPlaying {
                player.play()
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Ensure view fills entire screen
        uiView.frame = UIScreen.main.bounds
        context.coordinator.playerLayer?.frame = UIScreen.main.bounds
        
        // Handle play/pause
        if isPlaying {
            context.coordinator.player?.play()
        } else {
            context.coordinator.player?.pause()
        }
    }
    
    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.cleanup()
    }
}

// Container view to handle video player lifecycle
struct ShortFormVideoPlayer: View {
    let videoURL: URL
    let isCurrentlyVisible: Bool
    @State private var isPlaying: Bool = false
    
    var body: some View {
        ShortFormPlayer(url: videoURL, isPlaying: $isPlaying)
            .ignoresSafeArea()
            .onChange(of: isCurrentlyVisible) { newValue in
                isPlaying = newValue
            }
            .onAppear {
                isPlaying = isCurrentlyVisible
            }
            .onDisappear {
                isPlaying = false
            }
    }
}

#Preview {
    // Sample video URL for preview
    let sampleURL = URL(string: "hhttps://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/1080/Big_Buck_Bunny_1080_10s_30MB.mp4")!
    
    return ShortFormVideoPlayer(videoURL: sampleURL, isCurrentlyVisible: true)
        .frame(height: 400)
        .preferredColorScheme(.dark)
} 