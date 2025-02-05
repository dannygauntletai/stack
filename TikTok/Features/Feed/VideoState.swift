import AVFoundation
import Combine

class VideoStateManager: ObservableObject {
    @Published var isMuted = true
    @Published var isPlaying = true
    @Published var currentVideoIndex = 0
    
    static let shared = VideoStateManager()
    private init() {}
} 