import Foundation

struct Video: Identifiable, Codable {
    let id: String
    let videoUrl: String
    let caption: String
    let createdAt: Date
    let userId: String
    var likes: Int
    var comments: Int
    var shares: Int
    
    var dictionary: [String: Any] {
        return [
            "id": id,
            "videoUrl": videoUrl,
            "caption": caption,
            "createdAt": createdAt,
            "userId": userId,
            "likes": likes,
            "comments": comments,
            "shares": shares
        ]
    }
    
    // For testing purposes
    static let example = Video(
        id: UUID().uuidString,
        videoUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4",
        caption: "Test video #fun",
        createdAt: Date(),
        userId: UUID().uuidString,
        likes: 100,
        comments: 50,
        shares: 0
    )
} 