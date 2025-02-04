import SwiftUI
import Combine
import AVKit

struct UploadStatusPopup: View {
    let status: UploadStatus
    let videoName: String
    let caption: String
    let isPrivate: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            Text(headerText)
                .font(.headline)
                .foregroundColor(.white)
            
            // Progress or Status
            Group {
                switch status {
                case .ready:
                    Text("Ready to upload")
                case .uploading(let progress):
                    VStack(spacing: 8) {
                        ProgressView(value: progress) {
                            Text("\(Int(progress * 100))%")
                                .foregroundColor(.white)
                        }
                        .tint(.white)
                        Text("Uploading video...")
                    }
                case .processingURL:
                    Text("Processing...")
                case .savingToFirestore:
                    Text("Finalizing...")
                case .completed:
                    Text("Upload complete!")
                        .foregroundColor(.green)
                case .error(let message):
                    Text(message)
                        .foregroundColor(.red)
                }
            }
            .foregroundColor(.white)
            
            // Details
            VStack(alignment: .leading, spacing: 8) {
                Text("File: \(videoName)")
                Text("Caption: \(caption)")
                Text("Privacy: \(isPrivate ? "Private" : "Public")")
                Text("Time: \(Date().formatted(date: .numeric, time: .standard))")
            }
            .font(.system(size: 14))
            .foregroundColor(.white.opacity(0.8))
        }
        .padding()
        .frame(width: 300)
        .background(Color.black.opacity(0.95))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var headerText: String {
        switch status {
        case .completed:
            return "Upload Successful!"
        case .error:
            return "Upload Failed"
        default:
            return "Upload Status"
        }
    }
}

struct PostVideoView: View {
    let videoURL: URL
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = VideoUploadViewModel()
    @State private var caption = ""
    @State private var isPrivate = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @Binding var showURLInput: Bool
    @State private var uploadStatus: UploadStatus = .ready
    @State private var cancellables = Set<AnyCancellable>()
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var showUploadStatus = false
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    // Progress bar at top
                    if case .uploading(let progress) = uploadStatus {
                        GeometryReader { geometry in
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: geometry.size.width * progress, height: 2)
                                .animation(.linear, value: progress)
                        }
                        .frame(height: 2)
                    }
                    
                    // Header
                    HStack {
                        Button("Back") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("New Post")
                            .font(.headline)
                        
                        Spacer()
                    }
                    .padding()
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            // Video Preview
                            if let player = player {
                                VideoPlayer(player: player)
                                    .aspectRatio(9/16, contentMode: .fit)
                                    .frame(maxHeight: 400)
                                    .cornerRadius(12)
                                    .onAppear {
                                        player.play()
                                        NotificationCenter.default.addObserver(
                                            forName: .AVPlayerItemDidPlayToEndTime,
                                            object: player.currentItem,
                                            queue: .main
                                        ) { _ in
                                            player.seek(to: .zero)
                                            player.play()
                                        }
                                    }
                            } else if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(height: 400)
                            }
                        }
                    }
                    
                    // Stack these sections together at the bottom
                    VStack(spacing: 16) {
                        // Caption section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Caption")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text(caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        // Privacy toggle
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Privacy")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Toggle("Private video", isOn: $isPrivate)
                                .tint(.white)
                        }
                        .padding(.horizontal)
                        
                        // Post button
                        Button(action: uploadVideo) {
                            if case .uploading = uploadStatus {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.black)
                            } else {
                                Text("Post")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(uploadStatus == .ready ? Color.white : Color.white.opacity(0.5))
                        .foregroundColor(.black)
                        .cornerRadius(25)
                        .disabled(uploadStatus != .ready)
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                    .background(Color.black)
                }
                
                // Upload status popup
                if showUploadStatus {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    
                    UploadStatusPopup(
                        status: uploadStatus,
                        videoName: videoURL.lastPathComponent,
                        caption: caption,
                        isPrivate: isPrivate
                    )
                }
            }
            .background(Color.black)
            .navigationBarHidden(true)
            .interactiveDismissDisabled(uploadStatus != .ready && uploadStatus != .completed)
            .task {
                do {
                    let asset = AVURLAsset(url: videoURL)
                    let duration = try await asset.load(.duration)
                    
                    guard duration.seconds > 0 else {
                        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid video"])
                    }
                    
                    await MainActor.run {
                        self.player = AVPlayer(url: videoURL)
                        self.isLoading = false
                    }
                } catch {
                    print("Error loading video: \(error.localizedDescription)")
                    self.isLoading = false
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK") {
                    if case .completed = uploadStatus {
                        cleanupAndDismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
        .onChange(of: viewModel.uploadComplete) { completed in
            if completed {
                print("DEBUG: Upload complete, starting dismissal sequence")
                // Add slight delay to ensure state updates are complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("DEBUG: Executing cleanup and dismiss")
                    cleanupAndDismiss()
                }
            }
        }
        .onChange(of: viewModel.uploadStatus) { status in
            print("DEBUG: Upload status changed to: \(status)")
        }
        .overlay {
            if viewModel.isUploading {
                UploadStatusPopup(
                    status: viewModel.uploadStatus,
                    videoName: videoURL.lastPathComponent,
                    caption: caption,
                    isPrivate: isPrivate
                )
            }
        }
    }
    
    private func cleanupAndDismiss() {
        print("DEBUG: Starting cleanup")
        
        // Stop video playback first
        if let player = player {
            NotificationCenter.default.removeObserver(self, 
                name: .AVPlayerItemDidPlayToEndTime, 
                object: player.currentItem)
            player.pause()
            self.player = nil
        }
        
        print("DEBUG: Player cleanup complete")
        
        // Clean up other resources
        cancellables.removeAll()
        
        print("DEBUG: Starting view dismissal")
        
        // Dismiss in sequence with slight delays
        showURLInput = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            print("DEBUG: Calling final dismiss")
            dismiss()
        }
    }
    
    private func uploadVideo() {
        print("DEBUG: Starting upload in PostVideoView")
        showUploadStatus = true
        
        viewModel.uploadVideo(url: videoURL, caption: caption) { result in
            print("DEBUG: Upload completion handler called with result: \(result)")
            switch result {
            case .success(let video):
                print("DEBUG: Upload succeeded for video: \(video.id)")
            case .failure(let error):
                print("DEBUG: Upload failed with error: \(error.localizedDescription)")
                alertTitle = "Upload Failed"
                alertMessage = """
                    Error: \(error.localizedDescription)
                    Video: \(videoURL.lastPathComponent)
                    Time: \(Date().formatted(date: .numeric, time: .standard))
                    """
                showAlert = true
            }
        }
    }
} 