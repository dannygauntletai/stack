import Firebase
import Foundation

struct MessageFeedback: Equatable {
    let runId: String?
    var status: String // pending, submitted
}

struct ChatMessage: Identifiable, Equatable {
    let id: String
    let text: String?
    let imageURL: String?
    let isFromCurrentUser: Bool
    let timestamp: Date
    let senderId: String
    let sequence: Int
    let videoIds: [String]
    let feedback: MessageFeedback?
    
    init(document: QueryDocumentSnapshot, currentUserId: String) {
        let data = document.data()
        
        self.id = document.documentID
        self.text = data["content"] as? String
        self.imageURL = data["imageURL"] as? String
        self.senderId = data["senderId"] as? String ?? ""
        self.timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
        self.isFromCurrentUser = currentUserId == self.senderId
        self.sequence = data["sequence"] as? Int ?? 0
        
        // Parse video IDs if present
        var videoIds: [String] = []
        if let content = data["content"] as? String,
           content.contains("Video ID:") {
            let components = content.components(separatedBy: "Video ID:")
            for component in components.dropFirst() {
                let id = component.trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: .newlines)[0]
                videoIds.append(id)
            }
        }
        self.videoIds = videoIds
        
        // Get feedback data with trace_id
        if let feedbackData = data["feedback"] as? [String: Any] {
            self.feedback = MessageFeedback(
                runId: feedbackData["run_id"] as? String,
                status: feedbackData["status"] as? String ?? "pending"
            )
        } else {
            self.feedback = nil
        }
    }
    
    // Add initializer for previews
    init(id: String, text: String?, imageURL: String?, isFromCurrentUser: Bool, timestamp: Date, senderId: String, sequence: Int, videoIds: [String] = [], feedback: MessageFeedback? = nil) {
        self.id = id
        self.text = text
        self.imageURL = imageURL
        self.isFromCurrentUser = isFromCurrentUser
        self.timestamp = timestamp
        self.senderId = senderId
        self.sequence = sequence
        self.videoIds = videoIds
        self.feedback = feedback
    }
    
    var isRecommendationMessage: Bool {
        return !videoIds.isEmpty && text?.contains("Here are some relevant videos") == true
    }
} 