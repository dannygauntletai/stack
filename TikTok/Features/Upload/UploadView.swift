import SwiftUI
import PhotosUI
import AVKit
import SafariServices
import FirebaseStorage
import FirebaseFirestore
import Network
import FirebaseAuth

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
                    VideoPreviewView(
                        videoURL: url,
                        showVideoPreview: $showVideoPreview,
                        showURLInput: $showURLInput
                    )
                }
            }
            .sheet(isPresented: $showURLInput) {
                URLInputView(
                    urlString: $urlString,
                    showURLInput: $showURLInput
                )
            }
            .onChange(of: showVideoPreview, initial: false) { oldValue, newValue in
                if !newValue {
                    // Reset state when video preview is dismissed
                    selectedVideoURL = nil
                    urlString = ""
                }
            }
            .onChange(of: showURLInput, initial: false) { oldValue, newValue in
                if !newValue {
                    // Reset URL input state when dismissed
                    urlString = ""
                }
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
    @Binding var showURLInput: Bool
    
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
                    VideoPreviewView(
                        videoURL: url,
                        showVideoPreview: $showVideoPreview,
                        showURLInput: $showURLInput
                    )
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
    @Binding var showVideoPreview: Bool
    @Binding var showURLInput: Bool
    
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
                PostVideoView(
                    videoURL: videoURL,
                    caption: caption,
                    showVideoPreview: $showVideoPreview,
                    showURLInput: $showURLInput
                )
            }
            .task {
                do {
                    // Update to use AVURLAsset instead of AVAsset(url:)
                    let asset = AVURLAsset(url: videoURL)
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
    @StateObject private var uploadViewModel = VideoUploadViewModel()
    @State private var isPrivate = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var statusMessage = ""
    @Binding var showVideoPreview: Bool
    @Binding var showURLInput: Bool
    @State private var uploadStatus: UploadStatus = .ready
    
    enum UploadStatus: Equatable {
        case ready
        case uploading(progress: Double)
        case processingURL
        case savingToFirestore
        case completed
        case error(String)
        
        var message: String {
            switch self {
            case .ready:
                return "Ready to upload"
            case .uploading(let progress):
                return "Uploading: \(Int(progress * 100))%"
            case .processingURL:
                return "Processing video..."
            case .savingToFirestore:
                return "Saving video details..."
            case .completed:
                return "Upload completed!"
            case .error(let message):
                return "Error: \(message)"
            }
        }
        
        var isError: Bool {
            if case .error(_) = self { return true }
            return false
        }
        
        // Add custom equality comparison
        static func == (lhs: UploadStatus, rhs: UploadStatus) -> Bool {
            switch (lhs, rhs) {
            case (.ready, .ready):
                return true
            case (.uploading(let lhsProgress), .uploading(let rhsProgress)):
                return lhsProgress == rhsProgress
            case (.processingURL, .processingURL):
                return true
            case (.savingToFirestore, .savingToFirestore):
                return true
            case (.completed, .completed):
                return true
            case (.error(let lhsError), .error(let rhsError)):
                return lhsError == rhsError
            default:
                return false
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    TextField("Caption", text: .constant(caption))
                    Toggle("Private", isOn: $isPrivate)
                }
                
                // Single unified upload section
                Section {
                    Button(action: uploadVideo) {
                        if case .uploading = uploadStatus {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            Text("Post")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(uploadStatus != .ready)
                    
                    if uploadStatus != .ready {
                        if case .uploading(let progress) = uploadStatus {
                            ProgressView(value: progress, total: 1.0)
                                .progressViewStyle(.linear)
                        }
                        Text(uploadStatus.message)
                            .font(.footnote)
                            .foregroundColor(uploadStatus.isError ? .red : .secondary)
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
                    .disabled(!matches(uploadStatus, [.ready, .completed]))
                }
            }
            .onChange(of: uploadStatus, initial: false) { oldValue, newValue in
                if case .completed = newValue {
                    print("DEBUG: Upload completed, preparing to dismiss")
                    alertTitle = "Success"
                    alertMessage = "Your video has been uploaded successfully!"
                    showAlert = true
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK") {
                    if case .completed = uploadStatus {
                        print("DEBUG: Alert OK tapped, starting dismissal chain")
                        // Dismiss all views in sequence
                        dismiss() // Dismiss PostVideoView
                        showVideoPreview = false // Direct binding assignment
                        showURLInput = false // Direct binding assignment
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func uploadVideo() {
        uploadStatus = .uploading(progress: 0)
        
        uploadViewModel.uploadVideo(url: videoURL, caption: caption) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    uploadStatus = .completed
                case .failure(let error):
                    uploadStatus = .error(error.localizedDescription)
                }
            }
        }
    }
    
    // Helper function to check if status matches any of the allowed states
    private func matches(_ status: UploadStatus, _ allowed: [UploadStatus]) -> Bool {
        return allowed.contains { $0 == status }
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

class VideoUploadViewModel: ObservableObject {
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0
    @Published var errorMessage: String?
    @Published var statusMessage: String = ""
    
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    private var currentUploadTask: StorageUploadTask?
    private let monitor = NWPathMonitor()
    private var isNetworkAvailable = true
    
    init() {
        // Setup network monitoring
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isNetworkAvailable = path.status == .satisfied
        }
        monitor.start(queue: DispatchQueue.global())
    }
    
    deinit {
        monitor.cancel()
    }
    
    func uploadVideo(url: URL, caption: String, completion: @escaping (Result<Video, Error>) -> Void) {
        // Check if user is authenticated
        guard let currentUser = Auth.auth().currentUser else {
            let error = NSError(domain: "", code: -1, 
                userInfo: [NSLocalizedDescriptionKey: "User must be logged in to upload videos"])
            completion(.failure(error))
            return
        }
        
        // Prevent multiple simultaneous uploads
        guard !isUploading else { return }
        
        // Cancel any existing upload
        currentUploadTask?.cancel()
        
        isUploading = true
        uploadProgress = 0
        
        // Check network connectivity
        guard isNetworkAvailable else {
            DispatchQueue.main.async {
                self.isUploading = false
                let error = NSError(domain: "", code: -1, 
                    userInfo: [NSLocalizedDescriptionKey: "No internet connection. Please check your network and try again."])
                completion(.failure(error))
            }
            return
        }
        
        // Create a unique filename
        let filename = "\(UUID().uuidString).mp4"
        let storageRef = storage.reference().child("videos/\(filename)")
        
        // Create metadata
        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"
        
        // Upload the file
        currentUploadTask = storageRef.putFile(from: url, metadata: metadata)
        
        statusMessage = "Preparing upload..."
        
        currentUploadTask?.observe(.progress) { [weak self] snapshot in
            let percentComplete = Double(snapshot.progress?.completedUnitCount ?? 0) / 
                Double(snapshot.progress?.totalUnitCount ?? 1)
            DispatchQueue.main.async {
                self?.uploadProgress = percentComplete
                self?.statusMessage = "Uploading: \(Int(percentComplete * 100))%"
            }
        }
        
        currentUploadTask?.observe(.success) { [weak self] _ in
            print("DEBUG: Storage upload completed successfully")
            
            storageRef.downloadURL { url, error in
                if let error = error {
                    print("DEBUG: Failed to get download URL: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self?.isUploading = false
                        completion(.failure(error))
                    }
                    return
                }
                
                guard let downloadURL = url?.absoluteString else {
                    print("DEBUG: Download URL was nil")
                    let error = NSError(domain: "", code: -1, 
                        userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"])
                    completion(.failure(error))
                    return
                }
                
                print("DEBUG: Got download URL: \(downloadURL)")
                
                // Create video document with userId
                let video = Video(
                    id: UUID().uuidString,
                    videoUrl: downloadURL,
                    caption: caption,
                    createdAt: Date(),
                    userId: currentUser.uid,
                    likes: 0,
                    comments: 0,
                    shares: 0
                )
                
                // Since the video is uploaded successfully, we can consider this a success
                DispatchQueue.main.async {
                    self?.isUploading = false
                    completion(.success(video))
                }
                
                // Try to save to Firestore, but don't block the UI on it
                self?.db.collection("videos").document(video.id).setData(video.dictionary) { error in
                    if let error = error {
                        print("DEBUG: Firestore save failed: \(error.localizedDescription)")
                    } else {
                        print("DEBUG: Firestore save completed successfully")
                    }
                }
            }
        }
        
        currentUploadTask?.observe(.failure) { [weak self] snapshot in
            DispatchQueue.main.async {
                self?.isUploading = false
                if let error = snapshot.error {
                    let message = (error as NSError).domain == NSURLErrorDomain 
                        ? "Network error. Please check your connection and try again."
                        : error.localizedDescription
                    self?.statusMessage = "Error: \(message)"
                    self?.errorMessage = message
                    completion(.failure(error))
                }
            }
        }
    }
    
    func cancelUpload() {
        currentUploadTask?.cancel()
        isUploading = false
        uploadProgress = 0
    }
    
    func testFirestoreConnection() {
        db.collection("videos").limit(to: 1).getDocuments { snapshot, error in
            if let error = error {
                print("DEBUG: Firestore connection test failed: \(error.localizedDescription)")
            } else {
                print("DEBUG: Firestore connection test successful")
            }
        }
    }
}

#Preview {
    UploadView()
        .preferredColorScheme(.dark)
} 