import SwiftUI
import FirebaseStorage

struct StorageImageView<Content: View, Placeholder: View>: View {
    let gsURL: String
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    @State private var downloadURL: URL?
    
    init(
        gsURL: String,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.gsURL = gsURL
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let url = downloadURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        content(image)
                    case .failure:
                        placeholder()
                    case .empty:
                        placeholder()
                    @unknown default:
                        placeholder()
                    }
                }
            } else {
                placeholder()
            }
        }
        .task {
            guard gsURL.hasPrefix("gs://") else { return }
            do {
                let storageRef = Storage.storage().reference(forURL: gsURL)
                let url = try await storageRef.downloadURL()
                downloadURL = url
            } catch {
                print("Failed to load image: \(error.localizedDescription)")
            }
        }
    }
}
