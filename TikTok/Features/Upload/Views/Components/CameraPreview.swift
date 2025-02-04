import SwiftUI
import AVFoundation

class CameraManager: ObservableObject {
    @Published var permissionGranted = false
    let session = AVCaptureSession()
    private let deviceInput: AVCaptureDeviceInput?
    
    init() {
        // Get the back camera
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, 
                                                 for: .video,
                                                 position: .back) else {
            deviceInput = nil
            return
        }
        
        // Create device input
        do {
            deviceInput = try AVCaptureDeviceInput(device: device)
        } catch {
            print("Error setting up camera: \(error.localizedDescription)")
            deviceInput = nil
            return
        }
        
        // Check and request permission
        checkPermission()
    }
    
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if granted {
                        self?.setupSession()
                    }
                }
            }
        default:
            permissionGranted = false
        }
    }
    
    private func setupSession() {
        guard let deviceInput = deviceInput else { return }
        
        session.beginConfiguration()
        
        if session.canAddInput(deviceInput) {
            session.addInput(deviceInput)
        }
        
        session.commitConfiguration()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    func stop() {
        session.stopRunning()
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: CGRect.zero)
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}

struct CameraView: View {
    @StateObject private var cameraManager = CameraManager()
    @Environment(\.dismiss) private var dismiss
    
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
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 72, height: 72)
                        .overlay(
                            Circle()
                                .fill(Color.white)
                                .frame(width: 64, height: 64)
                        )
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
    }
}

#Preview {
    CameraView()
} 