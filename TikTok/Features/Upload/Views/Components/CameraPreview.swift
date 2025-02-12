import SwiftUI
import AVFoundation

class CameraManager: NSObject, ObservableObject {
    @Published var permissionGranted = false
    @Published var isRecording = false
    let session = AVCaptureSession()
    private let deviceInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var outputURL: URL?
    
    private let maxRecordingDuration: Double = 15.0 // 15 seconds max
    
    override init() {
        // Initialize video input
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
        
        // Initialize audio input
        audioInput = {
            guard let device = AVCaptureDevice.default(for: .audio) else { return nil }
            do {
                return try AVCaptureDeviceInput(device: device)
            } catch {
                print("Error setting up audio: \(error.localizedDescription)")
                return nil
            }
        }()
        
        movieOutput = AVCaptureMovieFileOutput()
        movieOutput?.maxRecordedDuration = CMTime(seconds: maxRecordingDuration, preferredTimescale: 600)
        
        // Call super.init()
        super.init()
        
        // Setup after initialization
        checkPermissions()
    }
    
    func checkPermissions() {
        // Check both video and audio permissions
        let videoStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch (videoStatus, audioStatus) {
        case (.authorized, .authorized):
            permissionGranted = true
            setupSession()
        case (.notDetermined, _):
            AVCaptureDevice.requestAccess(for: .video) { [weak self] videoGranted in
                if videoGranted {
                    AVCaptureDevice.requestAccess(for: .audio) { audioGranted in
                        DispatchQueue.main.async {
                            self?.permissionGranted = videoGranted && audioGranted
                            if self?.permissionGranted == true {
                                self?.setupSession()
                            }
                        }
                    }
                }
            }
        case (_, .notDetermined):
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] audioGranted in
                if audioGranted {
                    DispatchQueue.main.async {
                        self?.permissionGranted = true
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
        
        // Remove any existing inputs/outputs
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        
        // Add video input
        if session.canAddInput(deviceInput) {
            session.addInput(deviceInput)
        }
        
        // Add audio input
        if let audioInput = audioInput, session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }
        
        // Add movie output
        if let movieOutput = movieOutput, session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            
            // Configure video orientation after adding output
            if let connection = movieOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
            }
        }
        
        session.commitConfiguration()
        
        // Start session on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    func startRecording() {
        guard let movieOutput = movieOutput else { return }
        
        // Ensure we're on the main thread
        DispatchQueue.main.async {
            // Create unique file URL in temp directory
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "\(UUID().uuidString).mp4"
            let fileURL = tempDir.appendingPathComponent(fileName)
            
            // Remove any existing file
            try? FileManager.default.removeItem(at: fileURL)
            
            self.outputURL = fileURL
            movieOutput.startRecording(to: fileURL, recordingDelegate: self)
            self.isRecording = true
        }
    }
    
    func stopRecording() {
        movieOutput?.stopRecording()
        isRecording = false
    }
    
    func stop() {
        session.stopRunning()
        if isRecording {
            stopRecording()
        }
    }
}

// Add delegate methods
extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, 
                   didFinishRecordingTo outputFileURL: URL, 
                   from connections: [AVCaptureConnection], 
                   error: Error?) {
        
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
            
            if let error = error {
                print("Error recording video: \(error.localizedDescription)")
                return
            }
            
            // Post notification with recorded video URL
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
        let view = UIView(frame: UIScreen.main.bounds)  // Use full screen bounds
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        previewLayer.connection?.videoOrientation = .portrait  // Set orientation immediately
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
            layer.connection?.videoOrientation = .portrait
        }
    }
}