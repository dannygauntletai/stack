import Foundation

struct Video: Identifiable {
    let id: String
    let videoUrl: String
    let caption: String
    let createdAt: Date
    let userId: String
    let author: VideoAuthor
    var likes: Int
    var comments: Int
    var shares: Int
    let thumbnailUrl: String?
    let tags: [String]
    
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
            "profileImageUrl": author.profileImageUrl as Any,
            "tags": tags
        ]
        
        if let thumbnailUrl = thumbnailUrl {
            dict["thumbnailUrl"] = thumbnailUrl
        }
        
        return dict
    }
    
    init(
        id: String,
        videoUrl: String,
        caption: String,
        createdAt: Date,
        userId: String,
        author: VideoAuthor,
        likes: Int,
        comments: Int,
        shares: Int,
        thumbnailUrl: String?,
        tags: [String] = []
    ) {
        self.id = id
        self.videoUrl = videoUrl
        self.caption = caption
        self.createdAt = createdAt
        self.userId = userId
        self.author = author
        self.likes = likes
        self.comments = comments
        self.shares = shares
        self.thumbnailUrl = thumbnailUrl
        self.tags = tags
    }
} 