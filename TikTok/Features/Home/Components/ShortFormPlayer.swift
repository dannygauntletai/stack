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
        var looper: AVPlayerLooper?  // Add AVPlayerLooper
        
        init(_ parent: ShortFormPlayer) {
            self.parent = parent
        }
        
        func cleanup() {
            looper?.disableLooping()  // Cleanup looper
            looper = nil
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
        
        // Load video asynchronously
        Task {
            do {
                let asset = try await VideoCache.shared.getVideo(for: url)
                
                await MainActor.run {
                    // Create player with queue player for looping
                    let playerItem = AVPlayerItem(asset: asset)
                    let queuePlayer = AVQueuePlayer(playerItem: playerItem)
                    
                    // Create looper
                    let looper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
                    context.coordinator.looper = looper
                    
                    // Create and configure player layer
                    let playerLayer = AVPlayerLayer(player: queuePlayer)
                    playerLayer.videoGravity = .resizeAspectFill
                    playerLayer.frame = UIScreen.main.bounds
                    view.layer.addSublayer(playerLayer)
                    
                    // Store references
                    context.coordinator.player = queuePlayer
                    context.coordinator.playerLayer = playerLayer
                    
                    // Start playing if needed
                    if isPlaying {
                        queuePlayer.play()
                    }
                }
            } catch {
                print("Error loading video: \(error)")
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