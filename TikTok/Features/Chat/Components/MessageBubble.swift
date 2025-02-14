import SwiftUI
import FirebaseFirestore
import FirebaseStorage

struct MessageBubble: View {
    let message: ChatMessage
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    @State private var videoThumbnails: [(id: String, url: String)] = []
    
    func debugPrint(_ message: String) {
        print(message)
    }
    
    var body: some View {
        HStack {
            if message.isFromCurrentUser {
                Spacer()
            }
            
            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 8) {
                Text("") // Hidden debug text
                    .hidden()
                    .onAppear { debugPrint("🔍 Rendering message with \(message.videoIds.count) video IDs") }
                
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
                
                // Only show video thumbnails for recommendation messages
                if message.isRecommendationMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(videoThumbnails, id: \.id) { video in
                            Button(action: {
                                handleVideoTap(videoId: video.id)
                            }) {
                                AsyncImage(url: URL(string: video.url)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 200, height: 300)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                } placeholder: {
                                    ProgressView()
                                }
                            }
                        }
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            
            if !message.isFromCurrentUser {
                Spacer()
            }
        }
        .padding(.vertical, 2)
        .onAppear {
            debugPrint("👋 MessageBubble appeared")
            if message.isRecommendationMessage {
                debugPrint("🔄 Loading thumbnails for recommendation message")
                videoThumbnails = []
                loadVideoThumbnails()
            }
        }
        .onDisappear {
            debugPrint("👋 MessageBubble disappeared")
            videoThumbnails = []
        }
    }
    
    private func handleVideoTap(videoId: String) {
        print("👆 Video tapped: \(videoId)")
        NotificationCenter.default.post(
            name: .openVideo,
            object: nil,
            userInfo: ["videoId": videoId]
        )
        presentationMode.wrappedValue.dismiss()
    }
    
    private func loadVideoThumbnails() {
        let db = Firestore.firestore()
        let storage = Storage.storage()
        
        for videoId in message.videoIds {
            // Skip if we already have this thumbnail
            if videoThumbnails.contains(where: { $0.id == videoId }) {
                print("⏭️ Skipping already loaded thumbnail for video: \(videoId)")
                continue
            }
            
            print("🔍 Fetching thumbnail for video: \(videoId)")
            db.collection("videos").document(videoId).getDocument { snapshot, error in
                if let error = error {
                    print("❌ Error loading video thumbnail: \(error.localizedDescription)")
                    return
                }
                
                if let data = snapshot?.data(),
                   let thumbnailPath = data["thumbnailUrl"] as? String {
                    print("📂 Got thumbnail path: \(thumbnailPath)")
                    
                    let storageRef = storage.reference(forURL: thumbnailPath)
                    storageRef.downloadURL { url, error in
                        if let error = error {
                            print("❌ Error getting download URL: \(error.localizedDescription)")
                            return
                        }
                        
                        if let downloadUrl = url {
                            print("🔗 Got download URL: \(downloadUrl.absoluteString)")
                            DispatchQueue.main.async {
                                // Only add if not already present
                                if !videoThumbnails.contains(where: { $0.id == videoId }) {
                                    videoThumbnails.append((id: videoId, url: downloadUrl.absoluteString))
                                    print("📱 Updated thumbnails array, now contains \(videoThumbnails.count) items")
                                }
                            }
                        }
                    }
                } else {
                    print("⚠️ No thumbnail URL found for video: \(videoId)")
                }
            }
        }
    }
}

// Notification name for video opening
extension Notification.Name {
    static let openVideo = Notification.Name("openVideo")
}

#Preview {
    VStack {
        MessageBubble(message: ChatMessage(id: "1", text: "Hello there!", imageURL: nil, isFromCurrentUser: true, timestamp: Date(), senderId: "user1", sequence: 0))
        MessageBubble(message: ChatMessage(id: "2", text: "Hi! How are you?", imageURL: nil, isFromCurrentUser: false, timestamp: Date(), senderId: "user2", sequence: 0))
    }
} 