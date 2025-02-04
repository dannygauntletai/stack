import SwiftUI
import PhotosUI
import AVKit
import SafariServices

struct UploadView: View {
    @State private var showImagePicker = false
    @State private var showURLInput = false
    @State private var urlString = ""
    @State private var showVideoPreview = false
    @State private var selectedVideoURL: URL?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header text
                Text("Upload video")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top, 20)
                
                // Upload options
                VStack(spacing: 16) {
                    // Photo Library Option
                    UploadButton(
                        icon: "photo.fill",
                        title: "Upload from Device",
                        subtitle: "Choose from your camera roll"
                    ) {
                        showImagePicker = true
                    }
                    
                    // URL Option
                    UploadButton(
                        icon: "link",
                        title: "Add from URL",
                        subtitle: "Import video from the web"
                    ) {
                        showURLInput = true
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showImagePicker) {
                MediaPickerView { url in
                    selectedVideoURL = url
                    showVideoPreview = true
                }
            }
            .sheet(isPresented: $showVideoPreview) {
                if let url = selectedVideoURL {
                    VideoPreviewView(videoURL: url)
                }
            }
            .sheet(isPresented: $showURLInput) {
                URLInputView(urlString: $urlString)
            }
        }
    }
}

// Custom upload button
struct UploadButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .foregroundColor(.white)
    }
}

// Camera preview placeholder
struct CameraPreview: View {
    var body: some View {
        Text("Camera Preview")
            .font(.title)
            .foregroundColor(.secondary)
    }
}

// URL input view using native share sheet
struct URLInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var urlString: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showVideoPreview = false
    @State private var processedVideoURL: URL?
    
    func processVideoURL() async {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        // Check if it's a YouTube URL
        if urlString.contains("youtube.com") || urlString.contains("youtu.be") {
            // TODO: For now just show an alert that YouTube links aren't supported yet
            // In the future:
            // 1. Use YouTube Data API to validate video
            // 2. Extract video ID
            // 3. Use server-side processing to download and convert
            errorMessage = "YouTube videos will be supported in a future update"
            isLoading = false
            return
        }
        
        // For direct video URLs
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            // Check if it's a video content type
            if let mimeType = response.mimeType, mimeType.contains("video") {
                // Save to temporary file
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
                try data.write(to: tempURL)
                processedVideoURL = tempURL
                showVideoPreview = true
            } else {
                errorMessage = "URL does not point to a valid video"
            }
        } catch {
            errorMessage = "Failed to load video: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Paste video URL", text: $urlString)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .disabled(isLoading)
                }
                
                Section {
                    Button(action: {
                        Task {
                            await processVideoURL()
                        }
                    }) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Import")
                        }
                    }
                    .disabled(urlString.isEmpty || isLoading)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Import from URL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showVideoPreview) {
                if let url = processedVideoURL {
                    VideoPreviewView(videoURL: url)
                }
            }
        }
    }
}

// Safari View wrapper
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

struct VideoPreviewView: View {
    let videoURL: URL
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var loadError: Error?
    @State private var caption = ""
    @State private var showPostScreen = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let player = player {
                    // Video Preview
                    VideoPlayer(player: player)
                        .aspectRatio(9/16, contentMode: .fit)
                        .frame(maxHeight: .infinity)
                        .onAppear {
                            player.play()
                            // Loop video
                            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
                                player.seek(to: .zero)
                                player.play()
                            }
                        }
                
                    // Overlay controls
                    VStack {
                        // Top toolbar (trim/cut/effects buttons would go here)
                        HStack {
                            Button("Cancel") {
                                dismiss()
                            }
                            Spacer()
                        }
                        .padding()
                        
                        Spacer()
                        
                        // Bottom controls
                        VStack(spacing: 16) {
                            TextField("Add caption...", text: $caption)
                                .textFieldStyle(.roundedBorder)
                                .padding(.horizontal)
                            
                            Button(action: {
                                showPostScreen = true
                            }) {
                                Text("Next")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.black)
                                    .frame(width: 343, height: 44)
                                    .background(Color.white)
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.bottom, 30)
                    }
                } else if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if loadError != nil {
                    Text("Failed to load video")
                        .foregroundColor(.white)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showPostScreen) {
                PostVideoView(videoURL: videoURL, caption: caption)
            }
            .task {
                do {
                    // Validate video
                    let asset = AVAsset(url: videoURL)
                    let duration = try await asset.load(.duration)
                    
                    // Check if it's a valid video (has duration)
                    guard duration.seconds > 0 else {
                        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid video"])
                    }
                    
                    await MainActor.run {
                        self.player = AVPlayer(url: videoURL)
                        self.isLoading = false
                    }
                } catch {
                    await MainActor.run {
                        self.loadError = error
                        self.isLoading = false
                    }
                }
            }
        }
    }
}

// Final post screen
struct PostVideoView: View {
    let videoURL: URL
    let caption: String
    @Environment(\.dismiss) private var dismiss
    @State private var isPrivate = false
    
    var body: some View {
        NavigationView {
            Form {
                // Thumbnail selection would go here
                
                Section("Details") {
                    TextField("Caption", text: .constant(caption))
                    Toggle("Private", isOn: $isPrivate)
                }
                
                Section {
                    Button(action: {
                        // TODO: Handle actual upload
                        dismiss()
                    }) {
                        Text("Post")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Native Camera Picker using UIImagePickerController
struct CameraPickerView: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let completion: (URL?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.mediaTypes = ["public.movie"]
        picker.videoQuality = .typeHigh
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView
        
        init(_ parent: CameraPickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let url = info[.mediaURL] as? URL {
                parent.completion(url)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// Native Media Picker using PHPickerViewController
struct MediaPickerView: UIViewControllerRepresentable {
    let completion: (URL?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .videos
        config.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: MediaPickerView
        
        init(_ parent: MediaPickerView) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else {
                parent.dismiss()
                return
            }
            
            result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                if let url = url {
                    // Copy to temporary location
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                    try? FileManager.default.copyItem(at: url, to: tempURL)
                    
                    DispatchQueue.main.async {
                        self.parent.completion(tempURL)
                        self.parent.dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    UploadView()
        .preferredColorScheme(.dark)
} 