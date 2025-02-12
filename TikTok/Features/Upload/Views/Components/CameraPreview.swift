import SwiftUI
import AVFoundation

class CameraManager: NSObject, ObservableObject {
    @Published var permissionGranted = false
    @Published var isRecording = false
    let session = AVCaptureSession()
    private let deviceInput: AVCaptureDeviceInput?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var outputURL: URL?
    
    override init() {
        // Initialize properties before super.init()
        deviceInput = {
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, 
                                                     for: .video,
                                                     position: .back) else {
                return nil
            }
            
            do {
                return try AVCaptureDeviceInput(device: device)
            } catch {
                print("Error setting up camera: \(error.localizedDescription)")
                return nil
            }
        }()
        
        movieOutput = AVCaptureMovieFileOutput()
        
        // Call super.init()
        super.init()
        
        // Setup after initialization
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
        guard let deviceInput = deviceInput,
              let movieOutput = movieOutput else { return }
        
        session.beginConfiguration()
        
        if session.canAddInput(deviceInput) {
            session.addInput(deviceInput)
        }
        
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }
        
        session.commitConfiguration()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    func startRecording() {
        guard let movieOutput = movieOutput else { return }
        
        let documentsPath = FileManager.default.temporaryDirectory
        let outputPath = documentsPath.appendingPathComponent("\(UUID().uuidString).mov")
        outputURL = outputPath
        
        movieOutput.startRecording(to: outputPath, recordingDelegate: self)
        isRecording = true
    }
    
    func stopRecording() {
        movieOutput?.stopRecording()
        isRecording = false
    }
    
    func stop() {
        session.stopRunning()
    }
}

// Add delegate methods
extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, 
                   didFinishRecordingTo outputFileURL: URL, 
                   from connections: [AVCaptureConnection], 
                   error: Error?) {
        if let error = error {
            print("Error recording video: \(error.localizedDescription)")
            return
        }
        
        // Handle the recorded video URL
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
            // Here you would typically pass this URL to your VideoUploadViewModel
            NotificationCenter.default.post(
                name: .didFinishRecording,
                object: nil,
                userInfo: ["url": outputFileURL]
            )
        }
    }
}

// Add notification name
extension Notification.Name {
    static let didFinishRecording = Notification.Name("didFinishRecording")
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