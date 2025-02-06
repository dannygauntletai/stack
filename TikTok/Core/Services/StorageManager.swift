import Foundation
import FirebaseStorage
import UIKit

final class StorageManager {
    static let shared = StorageManager()
    private let storage = Storage.storage()
    
    private init() {}
    
    func uploadProfileImage(_ image: UIImage, userId: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw StorageError.invalidImageData
        }
        
        let storageRef = storage.reference()
        let profileImageRef = storageRef.child("profile_images/\(userId).jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await profileImageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await profileImageRef.downloadURL()
        return downloadURL.absoluteString
    }
}

enum StorageError: LocalizedError {
    case invalidImageData
    
    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Could not process image data"
        }
    }
} 