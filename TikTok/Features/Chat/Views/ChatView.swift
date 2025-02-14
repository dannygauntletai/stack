import SwiftUI
import Firebase
import PhotosUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var messageText = ""
    @State private var selectedItems: [PhotosPickerItem] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(viewModel.messages) { message in
                                ChatMessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        if let lastMessage = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Input area
                HStack(spacing: 12) {
                    PhotosPicker(selection: $selectedItems,
                                matching: .images,
                                photoLibrary: .shared()) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.gray)
                    }
                    
                    TextField("Message", text: $messageText, axis: .vertical)
                        .lineLimit(1...5)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(20)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.green)
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .onAppear {
            viewModel.startListeningToMessages()
        }
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        let text = messageText
        messageText = ""
        Task {
            await viewModel.sendMessage(text)
        }
    }
}

struct ChatMessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            // Add debug print
            let _ = print("Rendering message: \(message.text ?? "no text")")
            
            if message.isFromCurrentUser {
                Spacer()
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
                }
                
                Text(message.timestampString)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 4)
            }
            
            if !message.isFromCurrentUser {
                Spacer()
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    ChatView()
        .preferredColorScheme(.dark)
} 