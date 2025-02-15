import SwiftUI
import AVKit

struct VideoBottomSheet: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0
    @State private var player: AVPlayer?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismiss()
                    }
                
                VStack(spacing: 0) {
                    // Drag handle
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(.white.opacity(0.6))
                        .frame(width: 36, height: 5)
                        .padding(.top, 10)
                    
                    // Video player
                    VideoPlayerContainer(player: player)
                        .frame(height: geometry.size.height * 0.4)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                        .padding(.top, 10)
                    
                    // Video info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(video.caption)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack {
                            Text("@\(video.author.username)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Spacer()
                            Text("\(video.likes) likes")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(20)
                .offset(y: max(0, dragOffset))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.height
                        }
                        .onEnded { value in
                            if value.translation.height > 100 {
                                dismiss()
                            } else {
                                withAnimation(.spring()) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
            }
        }
        .onAppear {
            if let url = URL(string: video.videoUrl) {
                player = AVPlayer(url: url)
                player?.play()
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}

struct VideoPlayerContainer: UIViewRepresentable {
    let player: AVPlayer?
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        if let player = player {
            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(playerLayer)
            
            // Make playerLayer resize with view
            playerLayer.frame = view.bounds
            view.layer.addObserver(context.coordinator, 
                                 forKeyPath: "bounds",
                                 options: [],
                                 context: nil)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let playerLayer = uiView.layer.sublayers?.first as? AVPlayerLayer {
            playerLayer.frame = uiView.bounds
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(view: self)
    }
    
    class Coordinator: NSObject {
        let view: VideoPlayerContainer
        
        init(view: VideoPlayerContainer) {
            self.view = view
        }
        
        override func observeValue(forKeyPath keyPath: String?,
                                 of object: Any?,
                                 change: [NSKeyValueChangeKey : Any]?,
                                 context: UnsafeMutableRawPointer?) {
            if keyPath == "bounds" {
                if let layer = object as? CALayer,
                   let playerLayer = layer.sublayers?.first as? AVPlayerLayer {
                    playerLayer.frame = layer.bounds
                }
            }
        }
    }
} 