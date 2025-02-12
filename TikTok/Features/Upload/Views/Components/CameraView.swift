import SwiftUI
import AVFoundation

struct CameraView: View {
    @StateObject private var cameraManager = CameraManager()
    @Environment(\.dismiss) private var dismiss
    @State private var recordedVideoURL: URL?
    
    var body: some View {
        ZStack {
            if cameraManager.permissionGranted {
                CameraPreviewView(session: cameraManager.session)
                    .ignoresSafeArea()
                
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
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("Camera access is required")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Please enable camera access in Settings to record videos")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button(action: {
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                    }) {
                        Text("Open Settings")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(width: 160)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(4)
                    }
                    .padding(.top, 10)
                }
            }
        }
        .background(Color.black)
        .onAppear {
            setupNotifications()
        }
        .onDisappear {
            removeNotifications()
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
                // Here you would typically present the video preview
                // and pass the URL to VideoUploadViewModel
            }
        }
    }
    
    private func removeNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
} 