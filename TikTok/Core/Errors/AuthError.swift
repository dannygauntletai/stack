import Foundation

enum AuthError: LocalizedError {
    case userNotFound
    case invalidEmail
    case weakPassword
    case emailAlreadyInUse
    case networkError
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User not found"
        case .invalidEmail:
            return "Invalid email address"
        case .weakPassword:
            return "Password is too weak"
        case .emailAlreadyInUse:
            return "Email is already in use"
        case .networkError:
            return "Network error occurred"
        case .unknown:
            return "An unknown error occurred"
        }
    }
} 