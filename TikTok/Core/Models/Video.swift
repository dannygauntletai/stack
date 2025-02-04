import Foundation

struct Video: Identifiable {
    let id: String
    let url: URL
    let caption: String
    let createdAt: Date
    var interaction: VideoInteraction
    
    // For testing purposes
    static let example = Video(
        id: UUID().uuidString,
        url: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4")!,
        caption: "Test video #fun",
        createdAt: Date(),
        interaction: VideoInteraction(likes: 100, comments: 50, isLiked: false)
    )
} 