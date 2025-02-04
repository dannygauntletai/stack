import SwiftUI
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth
import Network

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
        
        let storageRef = storage.reference().child("videos/\(UUID().uuidString).mp4")
        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"
        
        currentUploadTask = storageRef.putFile(from: url, metadata: metadata)
        
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
                    self?.saveToFirestore(downloadURL: downloadURL, caption: caption, userId: currentUser.uid, completion: completion)
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
    }
    
    private func handleError(_ error: Error, completion: @escaping (Result<Video, Error>) -> Void) {
        isUploading = false
        uploadStatus = .error(error.localizedDescription)
        completion(.failure(error))
    }
    
    private func saveToFirestore(downloadURL: String, caption: String, userId: String, completion: @escaping (Result<Video, Error>) -> Void) {
        DispatchQueue.main.async {
            self.uploadStatus = .savingToFirestore(attempt: 1)
        }
        
        let video = Video(
            id: UUID().uuidString,
            videoUrl: downloadURL,
            caption: caption,
            createdAt: Date(),
            userId: userId,
            likes: 0,
            comments: 0,
            shares: 0
        )
        
        let videoData: [String: Any] = [
            "id": video.id,
            "videoUrl": video.videoUrl,
            "caption": caption,
            "createdAt": Timestamp(date: video.createdAt),
            "userId": video.userId,
            "likes": video.likes,
            "comments": video.comments,
            "shares": video.shares
        ]
        
        let docRef = db.collection("videos").document(video.id)
        
        docRef.setData(videoData) { [weak self] error in
            guard let self = self else { return }
            
            docRef.getDocument { [weak self] snapshot, verifyError in
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
} 