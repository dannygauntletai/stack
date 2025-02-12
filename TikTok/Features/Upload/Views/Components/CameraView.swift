import SwiftUI
import AVFoundation

struct CameraView: View {
    @StateObject private var cameraManager = CameraManager()
    @Environment(\.dismiss) private var dismiss
    @State private var recordedVideoURL: URL?
    @State private var showVideoPreview = false
    
    var body: some View {
        ZStack {
            if cameraManager.permissionGranted {
                GeometryReader { geometry in
                    CameraPreviewView(session: cameraManager.session)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .ignoresSafeArea()
                }
                
                // Camera controls overlay
                VStack {
                    HStack {
                        Button("Cancel") {
                            cameraManager.stop()
                            dismiss()
                        }
                        .foregroundColor(.white)
                        .padding()
                        
                        Spacer()
                    }
                    
                    Spacer()
                    
                    // Record button
                    Button(action: {
                        if cameraManager.isRecording {
                            cameraManager.stopRecording()
                        } else {
                            cameraManager.startRecording()
                        }
                    }) {
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 72, height: 72)
                            .overlay(
                                Circle()
                                    .fill(cameraManager.isRecording ? Color.red : Color.white)
                                    .frame(width: 64, height: 64)
                            )
                    }
                    .padding(.bottom, 30)
                }
            } else {
                CameraPermissionView()
            }
        }
        .background(Color.black)
        .sheet(isPresented: $showVideoPreview) {
            if let url = recordedVideoURL {
                PostVideoView(videoURL: url, showURLInput: .constant(false))
            }
        }
        .onAppear {
            setupNotifications()
            // Start session when view appears
            if cameraManager.permissionGranted {
                DispatchQueue.global(qos: .userInitiated).async {
                    if !self.cameraManager.session.isRunning {
                        self.cameraManager.session.startRunning()
                    }
                }
            }
        }
        .onDisappear {
            removeNotifications()
            cameraManager.stop()
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .didFinishRecording,
            object: nil,
            queue: .main
        ) { notification in
            if let url = notification.userInfo?["url"] as? URL {
                recordedVideoURL = url
                showVideoPreview = true
            }
        }
    }
    
    private func removeNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
} 