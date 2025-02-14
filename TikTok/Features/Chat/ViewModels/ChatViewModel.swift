import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import SwiftUI

@MainActor
class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    private var listenerRegistration: ListenerRegistration?
    let sessionId: String
    
    init() {
        self.sessionId = UUID().uuidString
    }
    
    deinit {
        // Since Firestore listeners are synchronous and thread-safe,
        // we can call remove directly
        listenerRegistration?.remove()
    }
    
    // MARK: - Message Handling
    
    func startListeningToMessages() {
        // Clean up any existing listener
        listenerRegistration?.remove()
        
        let db = Firestore.firestore()
        
        // Query messages ordered by sequence number
        let query = db.collection("messages")
            .whereField("sessionId", isEqualTo: sessionId)
            .order(by: "sequence", descending: false)
        
        // Set up the listener
        listenerRegistration = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error listening for messages: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents else { return }
            
            // Process messages
            let newMessages = documents.compactMap { document -> ChatMessage? in
                let data = document.data()
                
                guard let senderId = data["senderId"] as? String else { return nil }
                
                // Convert Firestore Timestamp to Date
                let timestamp: Date
                if let firestoreTimestamp = data["timestamp"] as? Timestamp {
                    timestamp = firestoreTimestamp.dateValue()
                } else {
                    print("Warning: Missing or invalid timestamp for message: \(document.documentID)")
                    timestamp = Date()
                }
                
                // Get the sequence number
                let sequence = data["sequence"] as? Int ?? 0
                
                return ChatMessage(
                    id: document.documentID,
                    text: data["content"] as? String,
                    imageURL: data["imageURL"] as? String,
                    isFromCurrentUser: senderId != "AI",
                    timestamp: timestamp,
                    senderId: senderId,
                    sequence: sequence
                )
            }
            
            // Keep ascending order (oldest first, newest last)
            Task { @MainActor in
                self.messages = newMessages // Already in correct order from Firestore
            }
        }
    }
    
    func sendMessage(_ text: String) async {
        guard !text.isEmpty,
              let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            // Get the current highest sequence number
            let lastMessage = messages.last
            let nextSequence = (lastMessage?.sequence ?? -1) + 1
            
            let messageData: [String: Any] = [
                "content": text.trimmingCharacters(in: .whitespacesAndNewlines),
                "senderId": userId,
                "sessionId": sessionId,
                "timestamp": FieldValue.serverTimestamp(),
                "type": "text",
                "sequence": nextSequence
            ]
            
            try await Firestore.firestore()
                .collection("messages")
                .addDocument(data: messageData)
        } catch {
            print("Error sending message: \(error.localizedDescription)")
        }
    }
    
    func sendMedia(_ imageData: Data) async {
        guard !imageData.isEmpty,
              let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            // Upload image
            let storageRef = Storage.storage().reference()
            let imageRef = storageRef.child("chat_images/\(UUID().uuidString).jpg")
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            _ = try await imageRef.putDataAsync(imageData, metadata: metadata)
            let downloadURL = try await imageRef.downloadURL()
            
            // Create message
            let messageData: [String: Any] = [
                "imageURL": downloadURL.absoluteString,
                "senderId": userId,
                "sessionId": sessionId,
                "timestamp": FieldValue.serverTimestamp(),
                "type": "image"
            ]
            
            try await Firestore.firestore()
                .collection("messages")
                .addDocument(data: messageData)
        } catch {
            print("Error sending image: \(error.localizedDescription)")
        }
    }
} 