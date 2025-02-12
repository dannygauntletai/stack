import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class EditProfileViewModel: ObservableObject {
    private let db = Firestore.firestore()
    
    func updateUsername(to newUsername: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            // Update username in users collection
            try await db.collection("users").document(userId).updateData([
                "username": newUsername
            ])
            
            // Get all videos by this user
            let videosSnapshot = try await db.collection("videos")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            // Update username in each video document
            for doc in videosSnapshot.documents {
                try await doc.reference.updateData([
                    "author.username": newUsername
                ])
            }
            
            NotificationCenter.default.post(
                name: .profileDidUpdate,
                object: nil
            )
        } catch {
            print("Error updating username: \(error)")
        }
    }
}

// Add notification name
extension Notification.Name {
    static let profileDidUpdate = Notification.Name("profileDidUpdate")
} 