import Foundation

struct Video: Identifiable {
    let id: String
    let videoUrl: String
    let caption: String
    let createdAt: Date
    let userId: String
    var likes: Int
    var comments: Int
    var shares: Int
    var thumbnailUrl: String?  // Optional thumbnail URL
    
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "videoUrl": videoUrl,
            "caption": caption,
            "createdAt": createdAt,
            "userId": userId,
            "likes": likes,
            "comments": comments,
            "shares": shares
        ]
        
        // Make sure thumbnailUrl is included when present
        if let thumbnailUrl = thumbnailUrl {
            dict["thumbnailUrl"] = thumbnailUrl
        }
        
        return dict
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