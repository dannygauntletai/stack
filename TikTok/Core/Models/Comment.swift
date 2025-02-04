import Foundation

struct Comment: Identifiable {
    let id: String
    let videoId: String
    let userId: String
    let text: String
    let createdAt: Date
    let likes: Int
    // Placeholder fields
    let username: String
    let profileImageUrl: String?
    
    var dictionary: [String: Any] {
        return [
            "id": id,
            "videoId": videoId,
            "userId": userId,
            "text": text,
            "createdAt": createdAt,
            "likes": likes,
            "username": username,
            "profileImageUrl": profileImageUrl ?? ""
        ]
    }
} 