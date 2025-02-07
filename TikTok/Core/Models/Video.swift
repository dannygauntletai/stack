import Foundation

struct Video: Identifiable {
    let id: String
    let videoUrl: String
    let caption: String
    let createdAt: Date
    let userId: String
    let author: VideoAuthor  // Add author
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
            "shares": shares,
            "username": author.username,
            "profileImageUrl": author.profileImageUrl as Any
        ]
        
        // Make sure thumbnailUrl is included when present
        if let thumbnailUrl = thumbnailUrl {
            dict["thumbnailUrl"] = thumbnailUrl
        }
        
        return dict
    }
} 