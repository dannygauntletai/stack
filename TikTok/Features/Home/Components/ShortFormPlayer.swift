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
    let visibility: VideoVisibility
    @State private var isPlaying: Bool = false
    @State private var showPlayPauseIndicator: Bool = false
    
    var body: some View {
        ZStack {
            ShortFormPlayer(url: videoURL, isPlaying: $isPlaying)
                .ignoresSafeArea()
            
            // Play/Pause indicator overlay
            if showPlayPauseIndicator {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 0)
                    .transition(.opacity)
            }
        }
        .onTapGesture {
            isPlaying.toggle()
            
            // Show indicator
            withAnimation(.easeOut(duration: 0.2)) {
                showPlayPauseIndicator = true
            }
            
            // Hide indicator after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 0.2)) {
                    showPlayPauseIndicator = false
                }
            }
        }
        .onChange(of: visibility) { newVisibility in
            isPlaying = newVisibility.visibilityPercentage > 0.5
        }
        .onAppear {
            isPlaying = visibility.visibilityPercentage > 0.5
        }
        .onDisappear {
            isPlaying = false
        }
    }
}

#Preview {
    // Sample video URL for preview
    let sampleURL = URL(string: "https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/1080/Big_Buck_Bunny_1080_10s_30MB.mp4")!
    
    return ShortFormVideoPlayer(
        videoURL: sampleURL,
        visibility: VideoVisibility(
            isFullyVisible: true,
            isPartiallyVisible: true,
            visibilityPercentage: 1.0
        )
    )
    .frame(height: 400)
    .preferredColorScheme(.dark)
} 