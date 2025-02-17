import SwiftUI
import Firebase
import PhotosUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @StateObject private var feedViewModel = ShortFormFeedViewModel()
    @State private var messageText = ""
    @State private var showSessionHistory = false
    @State private var shouldScrollToBottom = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            MessageListView(
                                messages: viewModel.messages,
                                feedViewModel: feedViewModel,
                                scrollProxy: proxy,
                                shouldScrollToBottom: $shouldScrollToBottom
                            )
                            .padding(.horizontal)
                            
                            // Add space for feedback buttons and scrolling
                            Spacer()
                                .frame(minHeight: 150) // Increased to ensure space for buttons
                        }
                        // Remove the fixed minHeight frame as it's causing issues
                        .frame(maxWidth: .infinity)
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .safeAreaInset(edge: .bottom) {
                        MessageInputView(
                            messageText: $messageText,
                            onSend: {
                                sendMessage()
                                shouldScrollToBottom = true
                            }
                        )
                        .background(Color(UIColor.systemBackground))
                    }
                }
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    historyButton
                }
            }
            .sheet(isPresented: $showSessionHistory) {
                ChatHistoryView(parentViewModel: viewModel)
                    .presentationDragIndicator(.visible)
            }
        }
        .onAppear {
            viewModel.startListeningToMessages()
            shouldScrollToBottom = true
        }
    }
    
    private var historyButton: some View {
        Button(action: { showSessionHistory = true }) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 20))
                .foregroundColor(.primary)
        }
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        let text = messageText
        messageText = ""  // Clear text immediately before sending
        
        Task {
            await viewModel.sendMessage(text)
        }
    }
}

struct MessageInputView: View {
    @Binding var messageText: String
    let onSend: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Message", text: $messageText, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(20)
            
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.blue)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// Update ChatHistoryView to show current session
struct ChatHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var parentViewModel: ChatViewModel
    @State private var sessions: [(id: String, timestamp: Date)] = []
    
    var body: some View {
        NavigationView {
            List {
                ForEach(sessions, id: \.id) { session in
                    Button(action: {
                        if session.id != parentViewModel.sessionId {  // Only switch if not current
                            parentViewModel.switchToSession(session.id)
                        }
                        dismiss()
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(session.id == parentViewModel.sessionId ? "Current Session" : "Chat Session")
                                    .fontWeight(.medium)
                                if session.id == parentViewModel.sessionId {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 14))
                                }
                            }
                            Text(session.timestamp.formatted())
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                    .foregroundColor(session.id == parentViewModel.sessionId ? .blue : .primary)
                }
            }
            .navigationTitle("Chat History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadSessions()
        }
    }
    
    private func loadSessions() {
        Task {
            if let loadedSessions = await parentViewModel.loadAllSessions() {
                await MainActor.run {
                    // Make sure current session is in the list
                    var updatedSessions = loadedSessions
                    if !updatedSessions.contains(where: { $0.id == parentViewModel.sessionId }) {
                        updatedSessions.insert((id: parentViewModel.sessionId, timestamp: Date()), at: 0)
                    }
                    sessions = updatedSessions
                }
            }
        }
    }
}

#Preview {
    ChatView()
        .preferredColorScheme(.dark)
} 