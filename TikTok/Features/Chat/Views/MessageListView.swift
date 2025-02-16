import SwiftUI

struct MessageListView: View {
    let messages: [ChatMessage]
    @ObservedObject var feedViewModel: ShortFormFeedViewModel
    let scrollProxy: ScrollViewProxy
    
    var body: some View {
        LazyVStack(spacing: 4) {
            ForEach(messages) { message in
                if message.isMultiPartMessage {
                    MultiPartMessageView(message: message, feedViewModel: feedViewModel)
                        .id(getLastPartId(message))
                } else {
                    MessageBubble(message: message, isLastPart: true)
                        .id(message.id)
                        .environmentObject(feedViewModel)
                }
            }
        }
        .padding(.horizontal)
        .onChange(of: messages.count) { _ in
            scrollToLatest()
        }
    }
    
    private func getLastPartId(_ message: ChatMessage) -> String {
        "\(message.id)-\(message.textParts.count - 1)"
    }
    
    private func scrollToLatest() {
        guard let lastMessage = messages.last else { return }
        
        withAnimation {
            let finalId = lastMessage.isMultiPartMessage ? 
                getLastPartId(lastMessage) : 
                lastMessage.id
            scrollProxy.scrollTo(finalId, anchor: .bottom)
        }
    }
}

struct MultiPartMessageView: View {
    let message: ChatMessage
    @ObservedObject var feedViewModel: ShortFormFeedViewModel
    
    var body: some View {
        ForEach(Array(message.textParts.enumerated()), id: \.offset) { index, part in
            MessageBubble(
                message: ChatMessage(
                    id: "\(message.id)-\(index)",
                    text: part,
                    imageURL: nil,
                    isFromCurrentUser: message.isFromCurrentUser,
                    timestamp: message.timestamp,
                    senderId: message.senderId,
                    sequence: message.sequence,
                    videoIds: index == message.textParts.count - 1 ? message.videoIds : [],
                    feedback: index == message.textParts.count - 1 ? message.feedback : nil
                ),
                isLastPart: index == message.textParts.count - 1
            )
            .environmentObject(feedViewModel)
        }
    }
} 