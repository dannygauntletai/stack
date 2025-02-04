import SwiftUI

struct URLInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var urlString: String
    @Binding var showURLInput: Bool
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showPostScreen = false
    @State private var processedVideoURL: URL?
    
    init(urlString: Binding<String>, showURLInput: Binding<Bool>) {
        self._urlString = urlString
        self._showURLInput = showURLInput
        // Set default test URL
        _urlString.wrappedValue = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4"
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
                                .frame(maxWidth: .infinity)
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
            .navigationTitle("Add from URL")
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
            .sheet(isPresented: $showPostScreen) {
                if let url = processedVideoURL {
                    PostVideoView(
                        videoURL: url,
                        showURLInput: $showURLInput
                    )
                }
            }
        }
    }
    
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
                showPostScreen = true
            } else {
                errorMessage = "URL does not point to a valid video"
            }
        } catch {
            errorMessage = "Failed to load video: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
} 