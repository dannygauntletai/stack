import SwiftUI

struct MessageListView: View {
    let messages: [ChatMessage]
    @ObservedObject var feedViewModel: ShortFormFeedViewModel
    let scrollProxy: ScrollViewProxy
    @Binding var shouldScrollToBottom: Bool
    
    var body: some View {
        LazyVStack(spacing: 4) {
            Spacer(minLength: 8)
            
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
            
            Color.clear
                .frame(height: 1)
                .id("bottom")
        }
        .onChange(of: messages.count) { _ in
            scrollToLatest()
        }
        .onChange(of: shouldScrollToBottom) { newValue in
            if newValue {
                scrollToLatest()
                shouldScrollToBottom = false
            }
        }
    }
    
    private func getLastPartId(_ message: ChatMessage) -> String {
        "\(message.id)-\(message.textParts.count - 1)"
    }
    
    private func scrollToLatest() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.2)) {
                scrollProxy.scrollTo("bottom", anchor: .bottom)
            }
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