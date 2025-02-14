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
    private var currentSequence: Int = 0
    
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
        
        // Query messages ordered by sequence number (false = ascending order: 0,1,2,3...)
        // This will show older messages at top, newer messages at bottom
        let query = db.collection("messages")
            .whereField("session_id", isEqualTo: sessionId)
            .order(by: "sequence", descending: false)  // descending: false is same as ascending order
        
        // Set up the listener with type annotations
        listenerRegistration = query.addSnapshotListener { [weak self] 
            (snapshot: QuerySnapshot?, error: Error?) in
            guard let self = self else { return }
            
            if let error = error {
                print("Error listening for messages: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents else { return }
            
            // Process messages
            let newMessages = documents.compactMap { document -> ChatMessage? in
                let data = document.data()
                
                return ChatMessage(
                    id: document.documentID,
                    text: data["content"] as? String,
                    imageURL: nil,
                    isFromCurrentUser: (data["role"] as? String) == "user",
                    timestamp: Date(timeIntervalSince1970: data["timestamp"] as? Double ?? 0),
                    senderId: data["role"] as? String ?? "",
                    sequence: data["sequence"] as? Int ?? 0
                )
            }
            
            Task { @MainActor in
                self.messages = newMessages
            }
        }
    }
    
    func sendMessage(_ text: String) async {
        guard !text.isEmpty else { return }
        
        do {
            // Prepare message data
            let messageData: [String: Any] = [
                "content": text.trimmingCharacters(in: .whitespacesAndNewlines),
                "type": "text",
                "session_id": sessionId,
                "sequence_number": currentSequence,
                "senderId": Auth.auth().currentUser?.uid ?? "anonymous"
            ]
            
            // Create URL request using AppEnvironment
            guard let url = URL(string: "\(AppEnvironment.baseURL)/agents/chat") else {
                print("Invalid URL")
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: messageData)
            
            // Send request
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("Error: Invalid response")
                return
            }
            
            // Increment sequence number after successful send
            currentSequence += 2  // Increment by 2 to account for both user and AI messages
            
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