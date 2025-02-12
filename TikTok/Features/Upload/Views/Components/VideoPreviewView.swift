import SwiftUI
import AVKit

struct VideoPreviewView: View {
    let videoURL: URL
    @StateObject private var uploadViewModel = VideoUploadViewModel()
    @State private var caption = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .frame(height: 400)
                
                TextField("Add a caption...", text: $caption)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Button(action: {
                    uploadViewModel.uploadVideo(url: videoURL, caption: caption) { result in
                        switch result {
                        case .success:
                            dismiss()
                        case .failure(let error):
                            print("Upload error: \(error.localizedDescription)")
                        }
                    }
                }) {
                    Text("Upload Video")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
} 