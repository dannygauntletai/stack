import SwiftUI
@preconcurrency import FirebaseStorage
@preconcurrency import FirebaseAuth
import FirebaseFirestore
import Network
import AVFoundation

@MainActor
final class VideoUploadViewModel: ObservableObject, @unchecked Sendable {
    @Published var isUploading = false
    @Published var uploadStatus: UploadStatus = .ready
    @Published var uploadProgress: Double = 0
    @Published var errorMessage: String?
    @Published var statusMessage: String = ""
    @Published var uploadComplete = false
    
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    private var currentUploadTask: StorageUploadTask?
    private let monitor = NWPathMonitor()
    private var isNetworkAvailable = true
    private let maxVideoDuration: Double = 15.0
    private let preferredBitRate: Float = 2_000_000 // 2Mbps
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isNetworkAvailable = path.status == .satisfied
            }
        }
        monitor.start(queue: DispatchQueue.global())
    }
    
    deinit {
        monitor.cancel()
    }
    
    func uploadVideo(url: URL, caption: String, completion: @escaping (Result<Video, Error>) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            let error = NSError(domain: "", code: -1, 
                userInfo: [NSLocalizedDescriptionKey: "User must be logged in to upload videos"])
            uploadStatus = .error("User must be logged in to upload videos")
            completion(.failure(error))
            return
        }
        
        guard !isUploading else { return }
        
        Task {
            do {
                let processedURL = try await processVideo(url: url)
                // Generate thumbnail from processed video
                guard let thumbnail = await generateThumbnail(from: processedURL) else {
                    let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate thumbnail"])
                    handleError(error, completion: completion)
                    return
                }
                
                let videoId = UUID().uuidString
                
                // Upload thumbnail
                let thumbnailURL = try await uploadThumbnail(for: videoId, image: thumbnail)
                
                let storageRef = storage.reference().child("videos/\(videoId).mp4")
                // Set proper metadata for streaming
                let metadata = StorageMetadata()
                metadata.contentType = "video/mp4"
                metadata.customMetadata = [
                    "fastStart": "true",  // Indicates MOOV atom is at start
                    "uploadDate": ISO8601DateFormatter().string(from: Date())
                ]
                
                // First check if video is in correct format
                let asset = AVURLAsset(url: processedURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
                let duration = try await asset.load(.duration)
                if duration.seconds == 0 {
                    throw NSError(domain: "", code: -1, 
                        userInfo: [NSLocalizedDescriptionKey: "Invalid video format"])
                }
                
                // Upload the video with proper metadata
                currentUploadTask = storageRef.putFile(from: processedURL, metadata: metadata)
                
                let taskReference = currentUploadTask
                taskReference?.observe(.resume) { [weak self] _ in
                    self?.isUploading = true
                }
                
                taskReference?.observe(.progress) { [weak self] snapshot in
                    let percentComplete = Double(snapshot.progress?.completedUnitCount ?? 0) / 
                        Double(snapshot.progress?.totalUnitCount ?? 1)
                    Task { @MainActor [weak self] in
                        self?.uploadProgress = percentComplete
                        self?.uploadStatus = .uploading(progress: percentComplete)
                    }
                }
                
                taskReference?.observe(.success) { [weak self] _ in
                    let gsURL = "gs://\(storageRef.bucket)/\(storageRef.fullPath)"
                    let uid = currentUser.uid // Capture value type
                    Task { @MainActor [weak self] in
                        self?.uploadStatus = .savingToFirestore(attempt: 1)
                        self?.saveToFirestore(
                            videoId: videoId,
                            videoURL: gsURL,
                            thumbnailURL: thumbnailURL,
                            caption: caption,
                            userId: uid,
                            completion: completion
                        )
                    }
                }
                
                taskReference?.observe(.failure) { [weak self] snapshot in
                    if let error = snapshot.error {
                        Task { @MainActor [weak self] in
                            self?.handleError(error, completion: completion)
                        }
                    }
                }
                
                isUploading = true
                uploadStatus = .uploading(progress: 0)
            } catch {
                await MainActor.run {
                    handleError(error, completion: completion)
                }
            }
        }
    }
    
    private func handleError(_ error: Error, completion: @escaping (Result<Video, Error>) -> Void) {
        isUploading = false
        uploadStatus = .error(error.localizedDescription)
        completion(.failure(error))
    }
    
    private func generateThumbnail(from url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        do {
            let result = try await imageGenerator.image(at: .zero)
            return UIImage(cgImage: result.image)
        } catch {
            print("Error generating thumbnail: \(error)")
            return nil
        }
    }
    
    private func uploadThumbnail(for videoId: String, image: UIImage) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        let thumbnailRef = storage.reference().child("thumbnails/\(videoId).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        do {
            _ = try await thumbnailRef.putDataAsync(imageData, metadata: metadata)
            return "gs://\(thumbnailRef.bucket)/\(thumbnailRef.fullPath)"
        } catch {
            throw error
        }
    }
    
    private func saveToFirestore(
        videoId: String,
        videoURL: String,
        thumbnailURL: String,
        caption: String,
        userId: String,
        completion: @escaping (Result<Video, Error>) -> Void
    ) {
        // First fetch the user data
        db.collection("users").document(userId).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.handleError(error, completion: completion)
                }
                return
            }
            
            guard let snapshot = snapshot, snapshot.exists, let userData = snapshot.data() else {
                DispatchQueue.main.async {
                    self.handleError(
                        NSError(domain: "", code: -1, 
                            userInfo: [NSLocalizedDescriptionKey: "User profile not found"]),
                        completion: completion
                    )
                }
                return
            }
            
            let username = userData["username"] as? String ?? "Unknown User"
            let profileImageUrl = userData["profileImageUrl"] as? String
            
            let video = Video(
                id: videoId,
                videoUrl: videoURL,
                caption: caption,
                createdAt: Date(),
                userId: userId,
                author: VideoAuthor(
                    id: userId,
                    username: username,
                    profileImageUrl: profileImageUrl
                ),
                likes: 0,
                comments: 0,
                shares: 0,
                thumbnailUrl: thumbnailURL
            )
            
            let docRef = db.collection("videos").document(video.id)
            
            docRef.setData(video.dictionary) { [weak self] error in
                guard let self = self else { return }
                
                docRef.getDocument { [weak self] (snapshot, verifyError) in
                    guard let self = self else { return }
                    
                    DispatchQueue.main.async {
                        if let error = error ?? verifyError {
                            self.handleError(error, completion: completion)
                            return
                        }
                        
                        // After successful upload, trigger health analysis
                        Task {
                            do {
                                // Health analysis will also handle vectorization
                                try await VideoService.shared.analyzeVideoHealth(videoUrl: videoURL)
                                let updatedVideo = try await VideoService.shared.getVideoDetails(videoId: video.id)
                                completion(.success(updatedVideo))
                            } catch {
                                print("Health analysis error: \(error)")
                                // Still complete the upload even if analysis fails
                                completion(.success(video))
                            }
                        }
                        
                        self.isUploading = false
                        self.uploadStatus = .completed
                        self.uploadComplete = true
                    }
                }
            }
        }
    }
    
    func cancelUpload() {
        currentUploadTask?.cancel()
        isUploading = false
        uploadStatus = .ready
        uploadProgress = 0
    }
    
    private func processVideo(url: URL) async throws -> URL {
        let asset = AVAsset(url: url)
        let duration = try await asset.load(.duration)
        
        // Create temp output URL
        let processedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        // Setup export session
        let composition = AVMutableComposition()
        guard let videoTrack = try await composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VideoError.processingFailed
        }
        
        // Get source video track
        guard let sourceVideoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoError.invalidSource
        }
        
        // Calculate time range
        let timeRange = CMTimeRange(
            start: .zero,
            duration: duration.seconds > maxVideoDuration 
                ? CMTime(seconds: maxVideoDuration, preferredTimescale: 600)
                : duration
        )
        
        // Add video track
        try videoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: .zero)
        
        // Configure export session
        let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        )
        
        guard let exportSession = exportSession else {
            throw VideoError.exportFailed
        }
        
        exportSession.outputURL = processedURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = nil
        exportSession.shouldOptimizeForNetworkUse = true
        
        if let videoComposition = exportSession.videoComposition {
            let settings = videoComposition.renderSize
            exportSession.fileLengthLimit = 10_000_000 // 10MB limit
        }
        
        // Export the video
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            throw VideoError.exportFailed
        }
        
        return processedURL
    }
    
    enum VideoError: Error {
        case processingFailed
        case invalidSource
        case exportFailed
    }
} 