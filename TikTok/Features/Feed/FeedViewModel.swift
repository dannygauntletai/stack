import Foundation
import FirebaseStorage

@MainActor
class FeedViewModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let storage = Storage.storage()
    
    func fetchVideos() async {
        isLoading = true
        defer { isLoading = false }
        
        // For testing, we'll create multiple instances of the same video
        self.videos = Array(repeating: Video.example, count: 10)
        
        // TODO: Implement actual Firebase storage fetch
        // let storageRef = storage.reference().child("videos")
        // ... fetch actual videos
    }
} 