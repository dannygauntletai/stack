import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let video: Video
    @State private var player: AVPlayer?
    @State private var isLoading = true
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let player = player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea(edges: .all)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
        }
        .background(Color.black)
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            cleanup()
        }
    }
    
    private func setupPlayer() {
        let player = AVPlayer(url: video.url)
        self.player = player
        
        // Hide loading after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isLoading = false
        }
        
        player.play()
        player.actionAtItemEnd = .none
        
        // Loop video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main) { _ in
                player.seek(to: .zero)
                player.play()
            }
    }
    
    private func cleanup() {
        player?.pause()
        player = nil
        isLoading = true
    }
} 