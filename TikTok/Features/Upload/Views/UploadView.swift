import SwiftUI
import PhotosUI

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct UploadView: View {
    @State private var showImagePicker = false
    @State private var showURLInput = false
    @State private var showCamera = false
    @State private var selectedVideoURL: URL?
    @State private var urlString = ""
    @State private var recordedVideoURL: IdentifiableURL?
    @State private var showPostView = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Upload options
                    VStack(spacing: 16) {
                        UploadButton(
                            icon: "camera.fill",
                            title: "Record Video",
                            subtitle: "Create a new video"
                        ) {
                            showCamera = true
                        }
                        
                        UploadButton(
                            icon: "photo.fill",
                            title: "Upload from Device",
                            subtitle: "Choose from your camera roll"
                        ) {
                            showImagePicker = true
                        }
                        
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
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    NavigationTitleView(title: "Upload")
                }
            }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showCamera) {
                CameraView { url in
                    recordedVideoURL = IdentifiableURL(url: url)
                    showPostView = true
                }
            }
            .sheet(isPresented: $showImagePicker) {
                MediaPickerView { url in
                    selectedVideoURL = url
                }
            }
            .sheet(isPresented: $showURLInput) {
                URLInputView(urlString: $urlString, showURLInput: $showURLInput)
            }
            .sheet(isPresented: .init(
                get: { selectedVideoURL != nil },
                set: { if !$0 { selectedVideoURL = nil } }
            )) {
                if let url = selectedVideoURL {
                    PostVideoView(videoURL: url, showURLInput: $showURLInput)
                }
            }
            .fullScreenCover(item: $recordedVideoURL) { identifiableURL in
                PostVideoView(videoURL: identifiableURL.url, showURLInput: $showURLInput)
            }
        }
    }
} 