import SwiftUI
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth
import Network
import AVFoundation

class VideoUploadViewModel: ObservableObject {
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
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isNetworkAvailable = path.status == .satisfied
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
                // Generate thumbnail from original video first
                guard let thumbnail = generateThumbnail(from: url) else {
                    let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate thumbnail"])
                    handleError(error, completion: completion)
                    return
                }
                
                // Then rotate the video
                let rotatedVideoURL = try await rotateVideo(url: url)
                
                let videoId = UUID().uuidString
                
                // Upload thumbnail
                let thumbnailURL = try await uploadThumbnail(for: videoId, image: thumbnail)
                
                let storageRef = storage.reference().child("videos/\(videoId).mp4")
                let metadata = StorageMetadata()
                metadata.contentType = "video/mp4"
                
                currentUploadTask = storageRef.putFile(from: rotatedVideoURL, metadata: metadata)
                
                let taskReference = currentUploadTask
                taskReference?.observe(.resume) { [weak self] _ in
                    self?.isUploading = true
                }
                
                taskReference?.observe(.progress) { [weak self] snapshot in
                    let percentComplete = Double(snapshot.progress?.completedUnitCount ?? 0) / 
                        Double(snapshot.progress?.totalUnitCount ?? 1)
                    DispatchQueue.main.async {
                        self?.uploadProgress = percentComplete
                        self?.uploadStatus = .uploading(progress: percentComplete)
                    }
                }
                
                taskReference?.observe(.success) { [weak self] _ in
                    storageRef.downloadURL { [weak self] url, error in
                        DispatchQueue.main.async {
                            if let error = error {
                                self?.handleError(error, completion: completion)
                                return
                            }
                            
                            guard let downloadURL = url?.absoluteString else {
                                let error = NSError(domain: "", code: -1, 
                                    userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"])
                                self?.handleError(error, completion: completion)
                                return
                            }
                            
                            self?.uploadStatus = .savingToFirestore(attempt: 1)
                            self?.saveToFirestore(
                                videoId: videoId,
                                videoURL: downloadURL,
                                thumbnailURL: thumbnailURL,
                                caption: caption,
                                userId: currentUser.uid,
                                completion: completion
                            )
                        }
                    }
                }
                
                taskReference?.observe(.failure) { [weak self] snapshot in
                    DispatchQueue.main.async {
                        if let error = snapshot.error {
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
    
    private func generateThumbnail(from url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
            let image = UIImage(cgImage: cgImage)
            
            // Rotate the thumbnail 180 degrees to compensate for video rotation
            let rotatedSize = CGSize(width: image.size.width, height: image.size.height) // Size stays same for 180
            UIGraphicsBeginImageContextWithOptions(rotatedSize, false, image.scale)
            let context = UIGraphicsGetCurrentContext()!
            
            // Translate and rotate
            context.translateBy(x: rotatedSize.width/2, y: rotatedSize.height/2)
            context.rotate(by: 2 * .pi)  // 360 degrees (keep this)
            image.draw(in: CGRect(
                x: -image.size.width/2,
                y: -image.size.height/2,
                width: image.size.width,
                height: image.size.height
            ))
            
            let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return rotatedImage
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
            let downloadURL = try await thumbnailRef.downloadURL()
            return downloadURL.absoluteString
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
        let video = Video(
            id: videoId,
            videoUrl: videoURL,
            caption: caption,
            createdAt: Date(),
            userId: userId,
            likes: 0,
            comments: 0,
            shares: 0,
            thumbnailUrl: thumbnailURL
        )
        
        let docRef = db.collection("videos").document(video.id)
        
        docRef.setData(video.dictionary) { [weak self] (error: Error?) in
            guard let self = self else { return }
            
            docRef.getDocument { [weak self] (snapshot: DocumentSnapshot?, verifyError: Error?) in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    if let error = error ?? verifyError {
                        self.handleError(error, completion: completion)
                        return
                    }
                    
                    guard let exists = snapshot?.exists, exists else {
                        self.handleError(NSError(domain: "", code: -1, 
                            userInfo: [NSLocalizedDescriptionKey: "Write verification failed"]), 
                            completion: completion)
                        return
                    }
                    
                    self.isUploading = false
                    self.uploadStatus = .completed
                    completion(.success(video))
                    self.uploadComplete = true
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
    
    func rotateVideo(url: URL) async throws -> URL {
        let asset = AVAsset(url: url)
        
        // Create composition
        let composition = AVMutableComposition()
        let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )
        
        // Get source video track
        let videoTrack = try await asset.loadTracks(withMediaType: .video).first!
        
        // Add video track to composition
        try compositionVideoTrack?.insertTimeRange(
            CMTimeRange(start: .zero, duration: try await asset.load(.duration)),
            of: videoTrack,
            at: .zero
        )
        
        // Get current transform and add -90 degrees rotation
        let currentTransform = videoTrack.preferredTransform
        let newTransform = currentTransform.rotated(by: -.pi/2)  // back to -90 degrees
        
        // Apply combined transform
        compositionVideoTrack?.preferredTransform = newTransform
        
        // Export with better configuration
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetPassthrough // Use passthrough to maintain quality
        ) else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not create export session"])
        }
        
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        // Copy audio track if it exists
        if let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first,
           let compositionAudioTrack = composition.addMutableTrack(
               withMediaType: .audio,
               preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            try? compositionAudioTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: try await asset.load(.duration)),
                of: audioTrack,
                at: .zero
            )
        }
        
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            throw exportSession.error ?? NSError(domain: "", code: -1)
        }
        
        return outputURL
    }
} 