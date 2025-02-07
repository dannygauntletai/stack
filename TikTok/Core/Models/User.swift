import Foundation

struct User: Identifiable {
    let uid: String
    let username: String
    let firstName: String
    let lastName: String
    let email: String
    let profileImageUrl: String?
    let createdAt: Date
    var followersCount: Int
    var followingCount: Int
    var restacksCount: Int
    
    // For Identifiable protocol
    var id: String { uid }
    
    // Computed properties
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    // Convert to dictionary for Firestore
    var asDictionary: [String: Any] {
        [
            "uid": uid,
            "username": username,
            "firstName": firstName,
            "lastName": lastName,
            "email": email,
            "profileImageUrl": profileImageUrl ?? "",
            "createdAt": createdAt,
            "followersCount": followersCount,
            "followingCount": followingCount,
            "restacksCount": restacksCount
        ]
    }
}

// Extension for mock data and testing
extension User {
    static let mockUser = User(
        uid: "123",
        username: "johndoe",
        firstName: "John",
        lastName: "Doe",
        email: "john@example.com",
        profileImageUrl: nil,
        createdAt: Date(),
        followersCount: 0,
        followingCount: 0,
        restacksCount: 0
    )
} 