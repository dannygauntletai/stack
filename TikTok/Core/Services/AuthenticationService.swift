import Foundation
import FirebaseAuth
import FirebaseFirestore
import UIKit
import FirebaseStorage

protocol AuthenticationServiceProtocol {
    func signIn(withEmail email: String, password: String) async throws -> FirebaseAuth.User
    func signUp(withEmail email: String, password: String) async throws -> FirebaseAuth.User
    func signOut() throws
    var currentUser: FirebaseAuth.User? { get }
    func createUserProfile(username: String, firstName: String, lastName: String, profileImage: UIImage?) async throws
}

final class AuthenticationService: AuthenticationServiceProtocol {
    static let shared = AuthenticationService()
    
    private init() {}
    
    var currentUser: FirebaseAuth.User? {
        Auth.auth().currentUser
    }
    
    // Return Firebase User for auth operations
    func signIn(withEmail email: String, password: String) async throws -> FirebaseAuth.User {
        let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
        return authResult.user
    }
    
    func signUp(withEmail email: String, password: String) async throws -> FirebaseAuth.User {
        let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
        return authResult.user
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
    }
    
    func createUserProfile(username: String, firstName: String, lastName: String, profileImage: UIImage?) async throws {
        guard let uid = Auth.auth().currentUser?.uid,
              let email = Auth.auth().currentUser?.email else {
            throw AuthError.userNotFound
        }
        
        // Upload profile image if provided
        var profileImageUrl: String?
        if let image = profileImage {
            profileImageUrl = try await StorageManager.shared.uploadProfileImage(image, userId: uid)
        }
        
        // Create user model
        let user = User(
            uid: uid,
            username: username,
            firstName: firstName,
            lastName: lastName,
            email: email,
            profileImageUrl: profileImageUrl,
            createdAt: Date()
        )
        
        // Save to Firestore using dictionary
        try await Firestore.firestore()
            .collection("users")
            .document(uid)
            .setData(user.asDictionary)
    }
} 