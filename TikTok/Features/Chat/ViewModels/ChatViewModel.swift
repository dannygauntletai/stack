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
    @Published var sessionId: String
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
                print("❌ Error listening for messages: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents else { 
                print("⚠️ No documents in snapshot")
                return 
            }
            
            print("📥 Received \(documents.count) documents from Firestore")
            let newMessages = self.processMessages(documents)
            
            Task { @MainActor in
                print("🔄 Updating messages array with \(newMessages.count) messages")
                self.messages = newMessages
                print("✅ Messages array updated, now contains \(self.messages.count) messages")
            }
        }
    }
    
    private func processMessages(_ documents: [QueryDocumentSnapshot]) -> [ChatMessage] {
        print("Processing \(documents.count) messages")
        
        let newMessages = documents.compactMap { document -> ChatMessage? in
            let data = document.data()
            
            // Get the raw content and feedback data
            guard let content = data["content"] as? String else { 
                print("⚠️ No content found in message")
                return nil 
            }
            
            // Parse video IDs and clean up text if present
            var cleanedText = content
            var videoIds: [String] = []
            
            // Extract video IDs and remove them from display text
            if content.contains("Video ID:") {
                print("🎥 Found Video ID in message")
                let components = content.components(separatedBy: "Video ID:")
                cleanedText = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Extract IDs from remaining components
                for component in components.dropFirst() {
                    let id = component.trimmingCharacters(in: .whitespacesAndNewlines)
                        .components(separatedBy: .newlines)[0]
                    videoIds.append(id)
                }
            }
            
            // Extract feedback data including trace_id and run_id
            print("📝 Raw message data: \(data)")  // Debug log
            
            // Get feedback data from the correct path
            if let feedbackData = data["feedback"] as? [String: Any] {
                if let runId = feedbackData["run_id"] as? String {
                    print("🔍 Found run_id in feedback: \(runId)")
                    ChatService.shared.setRunId(runId, for: document.documentID)
                }
            }
            
            let message = ChatMessage(
                id: document.documentID,
                text: cleanedText,
                imageURL: data["imageURL"] as? String,
                isFromCurrentUser: (data["role"] as? String) == "user",
                timestamp: Date(timeIntervalSince1970: data["timestamp"] as? Double ?? 0),
                senderId: data["senderId"] as? String ?? "",
                sequence: data["sequence"] as? Int ?? 0,
                videoIds: videoIds,
                feedback: (data["feedback"] as? [String: Any]).map { feedbackData in
                    MessageFeedback(
                        runId: feedbackData["run_id"] as? String,
                        status: feedbackData["status"] as? String ?? "pending"
                    )
                }
            )
            
            print("📱 Created message with run_id: \(message.feedback?.runId ?? "none")")
            return message
        }
        
        print("✨ Processed \(newMessages.count) messages")
        return newMessages
    }
    
    private func storeAIResponse(_ responseData: [String: Any]) async throws {
        guard let message = responseData["message"] as? [String: Any],
              let text = message["text"] as? String,
              let feedback = message["feedback"] as? [String: Any] else {
            print("❌ Invalid AI response format")
            return
        }
        
        let messageData: [String: Any] = [
            "content": text,
            "type": "text",
            "session_id": sessionId,
            "role": "assistant",
            "sequence": currentSequence + 1,
            "timestamp": FieldValue.serverTimestamp(),
            "senderId": "ai",
            "feedback": feedback  // This includes the trace_id
        ]
        
        try await Firestore.firestore()
            .collection("messages")
            .addDocument(data: messageData)
    }
    
    func sendMessage(_ text: String) async {
        guard !text.isEmpty else { return }
        
        do {
            // First store user's message directly in Firestore
            let userMessage: [String: Any] = [
                "content": text.trimmingCharacters(in: .whitespacesAndNewlines),
                "type": "text",
                "session_id": sessionId,
                "role": "user",
                "sequence": currentSequence,
                "timestamp": FieldValue.serverTimestamp(),
                "senderId": Auth.auth().currentUser?.uid ?? "anonymous"
            ]
            
            try await Firestore.firestore()
                .collection("messages")
                .addDocument(data: userMessage)
            
            // Then get AI response
            let requestData: [String: Any] = [
                "content": text.trimmingCharacters(in: .whitespacesAndNewlines),
                "type": "text",
                "session_id": sessionId,
                "sequence_number": currentSequence + 1
            ]
            
            guard let url = URL(string: "\(AppEnvironment.baseURL)/agents/chat") else {
                print("Invalid URL")
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: requestData)
            
            let (_, _) = try await URLSession.shared.data(for: request)
            
            // Backend handles storing the AI response
            // Our Firestore listener will pick up the new message automatically
            currentSequence += 2
            
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
    
    // Add new methods for session management
    func loadAllSessions() async -> [(id: String, timestamp: Date)]? {
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("messages")
                .order(by: "timestamp", descending: true)
                .getDocuments()
            
            // Get unique session IDs with their timestamps
            var sessionsDict: [String: Date] = [:]
            for document in snapshot.documents {
                if let sessionId = document.data()["session_id"] as? String,
                   let timestamp = (document.data()["timestamp"] as? Timestamp)?.dateValue() {
                    // Only keep the most recent timestamp for each session
                    if sessionsDict[sessionId] == nil {
                        sessionsDict[sessionId] = timestamp
                    }
                }
            }
            
            // Convert to array and sort by timestamp
            let sessions = sessionsDict.map { (id: $0.key, timestamp: $0.value) }
                .sorted { $0.timestamp > $1.timestamp }
            
            return sessions
            
        } catch {
            print("Error loading sessions: \(error.localizedDescription)")
            return nil
        }
    }
    
    func switchToSession(_ newSessionId: String) {
        // Clean up existing listener
        listenerRegistration?.remove()
        
        // Update session ID
        sessionId = newSessionId
        
        // Start listening to the new session
        startListeningToMessages()
    }
} 