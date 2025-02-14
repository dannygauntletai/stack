import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            if message.isFromCurrentUser {
                Spacer() // User messages on the right
            }
            
            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading) {
                if let text = message.text {
                    Text(text)
                        .padding(12)
                        .background(message.isFromCurrentUser ? Color.blue : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                if let imageURL = message.imageURL {
                    AsyncImage(url: URL(string: imageURL)) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } placeholder: {
                        ProgressView()
                    }
                    .background(message.isFromCurrentUser ? Color.blue : Color.gray.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                Text(message.timestampString)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 4)
            }
            
            if !message.isFromCurrentUser {
                Spacer() // AI messages on the left
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    VStack {
        MessageBubble(message: ChatMessage(id: "1", text: "Hello there!", imageURL: nil, isFromCurrentUser: true, timestamp: Date(), senderId: "user1", sequence: 0))
        MessageBubble(message: ChatMessage(id: "2", text: "Hi! How are you?", imageURL: nil, isFromCurrentUser: false, timestamp: Date(), senderId: "user2", sequence: 0))
    }
} 