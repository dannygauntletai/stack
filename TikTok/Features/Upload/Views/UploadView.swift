import SwiftUI
import PhotosUI

struct UploadView: View {
    @State private var showImagePicker = false
    @State private var showURLInput = false
    @State private var showCamera = false
    @State private var selectedVideoURL: URL?
    @State private var urlString = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header text
                    Text("Upload video")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.top, 20)
                    
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
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showCamera) {
                CameraView()
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
        }
    }
} 