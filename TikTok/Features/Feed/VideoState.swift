import AVFoundation
import Combine

class VideoStateManager: ObservableObject {
    @Published var isMuted = true
    @Published var isPlaying = true
    @Published var currentVideoIndex = 0
    @Published var currentVideo: Video?
    
    static let shared = VideoStateManager()
    private init() {}
} 