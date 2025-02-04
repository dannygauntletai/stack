import Foundation
import FirebaseAuth

protocol AuthenticationServiceProtocol {
    func signIn(withEmail email: String, password: String) async throws -> User
    func signUp(withEmail email: String, password: String) async throws -> User
    func signOut() throws
    var currentUser: User? { get }
}

final class AuthenticationService: AuthenticationServiceProtocol {
    static let shared = AuthenticationService()
    
    private init() {}
    
    var currentUser: User? {
        Auth.auth().currentUser
    }
    
    func signIn(withEmail email: String, password: String) async throws -> User {
        let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
        return authResult.user
    }
    
    func signUp(withEmail email: String, password: String) async throws -> User {
        let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
        return authResult.user
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
    }
} 