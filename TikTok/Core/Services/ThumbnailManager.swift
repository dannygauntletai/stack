import AVFoundation
import FirebaseStorage
import FirebaseFirestore

actor ThumbnailManager {
    static let shared = ThumbnailManager()
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    private var processingVideos = Set<String>()  // Track videos being processed
    
    private init() {}
    
    func ensureThumbnail(for video: Video) async {
        // Skip if already has thumbnail or is being processed
        guard video.thumbnailUrl == nil,
              !processingVideos.contains(video.id) else {
            return
        }
        
        processingVideos.insert(video.id)
        defer { processingVideos.remove(video.id) }
        
        do {
            // Download first frame of video
            guard let videoURL = URL(string: video.videoUrl) else { return }
            
            let asset = AVAsset(url: videoURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            
            let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
            let thumbnail = UIImage(cgImage: cgImage)
            
            // Upload thumbnail
            guard let imageData = thumbnail.jpegData(compressionQuality: 0.7) else { return }
            
            let thumbnailRef = storage.reference().child("thumbnails/\(video.id).jpg")
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            _ = try await thumbnailRef.putDataAsync(imageData, metadata: metadata)
            let downloadURL = try await thumbnailRef.downloadURL()
            
            // Update video document with thumbnail URL
            try await db.collection("videos").document(video.id).updateData([
                "thumbnailUrl": downloadURL.absoluteString
            ])
            
        } catch {
            print("Error generating thumbnail for video \(video.id): \(error)")
        }
    }
} 