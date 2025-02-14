import Firebase
import Foundation

struct ChatMessage: Identifiable, Equatable {
    let id: String
    let text: String?
    let imageURL: String?
    let isFromCurrentUser: Bool
    let timestamp: Date
    let senderId: String
    let sequence: Int
    let videoIds: [String]  // This is now populated by ChatViewModel
    
    var timestampString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        // Set timezone to local user's timezone
        formatter.timeZone = .current
        // Add calendar and locale for consistency
        formatter.calendar = Calendar.current
        formatter.locale = Locale.current
        
        // For messages from today, show only time
        // For older messages, show date and time
        if Calendar.current.isDateInToday(timestamp) {
            formatter.dateStyle = .none
        } else {
            formatter.dateStyle = .short
        }
        
        return formatter.string(from: timestamp)
    }
    
    init(document: QueryDocumentSnapshot, currentUserId: String) {
        let data = document.data()
        
        self.id = document.documentID
        self.text = data["text"] as? String
        self.imageURL = data["imageURL"] as? String
        self.senderId = data["senderId"] as? String ?? ""
        self.timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
        self.isFromCurrentUser = currentUserId == self.senderId
        self.sequence = data["sequence"] as? Int ?? 0
        self.videoIds = []  // Default to empty array
    }
    
    // Add initializer for previews
    init(id: String, text: String?, imageURL: String?, isFromCurrentUser: Bool, timestamp: Date, senderId: String, sequence: Int, videoIds: [String] = []) {
        self.id = id
        self.text = text
        self.imageURL = imageURL
        self.isFromCurrentUser = isFromCurrentUser
        self.timestamp = timestamp
        self.senderId = senderId
        self.sequence = sequence
        self.videoIds = videoIds
    }
} 