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
    private let db = Firestore.firestore()  // Just get the instance
    private var currentUploadTask: StorageUploadTask?
    private let monitor = NWPathMonitor()
    private var isNetworkAvailable = true
    
    init() {
        // Log both Storage and Firestore setup
        print("""
        DEBUG: Firebase Setup Check:
        - Storage Instance: \(storage)
        - Storage Bucket: \(storage.reference().bucket)
        - Firestore Instance: \(db)
        - Firestore Database: \(db.app.options.projectID ?? "unknown")
        """)
        
        // Check Storage videos folder
        storage.reference().child("videos").listAll { result, error in
            print("""
            DEBUG: Storage Videos Check:
            - Error: \(String(describing: error))
            - Items Count: \(result?.items.count ?? 0)
            - Latest Items: \(result?.items.prefix(5).map { $0.name } ?? [])
            """)
        }
        
        // Check Firestore videos collection
        db.collection("videos").getDocuments { snapshot, error in
            print("""
            DEBUG: Firestore Videos Check:
            - Error: \(String(describing: error))
            - Document Count: \(snapshot?.documents.count ?? 0)
            - Latest Documents: \(snapshot?.documents.prefix(5).map { doc in
                "[\(doc.documentID): \(doc.data())]"
            } ?? [])
            """)
        }
        
        // Validate Firestore setup
        print("""
        DEBUG: Firestore Setup Check:
        - Database Instance: \(db)
        - Database ID: \(db.app.options.projectID ?? "unknown")
        """)
        
        // Test connection by fetching collection
        db.collection("videos").getDocuments { snapshot, error in
            if let error = error {
                print("""
                DEBUG: ❌ Firestore Connection Error:
                - Error: \(error.localizedDescription)
                - Details: \(error as NSError)
                """)
            } else {
                print("""
                DEBUG: ✅ Firestore Connection Successful:
                - Collection 'videos' exists
                - Document count: \(snapshot?.documents.count ?? 0)
                - Documents: \(snapshot?.documents.map { $0.documentID } ?? [])
                """)
            }
        }
        
        // Also verify the collection path
        print("DEBUG: Verifying collection path:")
        db.collection("videos").document("test").getDocument { snapshot, error in
            if let exists = snapshot?.exists {
                print("DEBUG: Test document exists: \(exists)")
                if let data = snapshot?.data() {
                    print("DEBUG: Test document data: \(data)")
                }
            }
        }
        
        // Network monitor setup
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
        
        print("DEBUG: Starting upload process")
        
        // Configure storage reference with retry settings
        let storageRef = storage.reference().child("videos/\(UUID().uuidString).mp4")
        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"
        
        // Create the upload task with maximum retry
        currentUploadTask = storageRef.putFile(from: url, metadata: metadata)
        
        // Configure retry behavior
        let taskReference = currentUploadTask
        taskReference?.observe(.resume) { [weak self] _ in
            print("DEBUG: Upload resumed")
            self?.isUploading = true
        }
        
        taskReference?.observe(.progress) { [weak self] snapshot in
            let percentComplete = Double(snapshot.progress?.completedUnitCount ?? 0) / 
                Double(snapshot.progress?.totalUnitCount ?? 1)
            print("DEBUG: Upload progress: \(Int(percentComplete * 100))%")
            DispatchQueue.main.async {
                self?.uploadProgress = percentComplete
                self?.uploadStatus = .uploading(progress: percentComplete)
            }
        }
        
        taskReference?.observe(.success) { [weak self] _ in
            print("DEBUG: Storage upload completed successfully")
            
            // Get download URL immediately after successful upload
            storageRef.downloadURL { url, error in
                print("DEBUG: Getting download URL")
                DispatchQueue.main.async {
                    if let error = error {
                        print("DEBUG: Failed to get download URL: \(error.localizedDescription)")
                        self?.handleError(error, completion: completion)
                        return
                    }
                    
                    guard let downloadURL = url?.absoluteString else {
                        print("DEBUG: Download URL is nil")
                        let error = NSError(domain: "", code: -1, 
                            userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"])
                        self?.handleError(error, completion: completion)
                        return
                    }
                    
                    print("DEBUG: Got download URL: \(downloadURL)")
                    self?.uploadStatus = .savingToFirestore(attempt: 1)
                    self?.saveToFirestore(downloadURL: downloadURL, caption: caption, completion: completion)
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
        
        // Start the upload
        isUploading = true
        uploadStatus = .uploading(progress: 0)
    }
    
    private func handleError(_ error: Error, completion: @escaping (Result<Video, Error>) -> Void) {
        isUploading = false
        uploadStatus = .error(error.localizedDescription)
        completion(.failure(error))
    }
    
    private func saveToFirestore(downloadURL: String, caption: String, completion: @escaping (Result<Video, Error>) -> Void) {
        print("DEBUG: Starting Firestore save")
        
        // Add collection path logging
        print("""
        DEBUG: Firestore Write Details:
        - Collection Path: \(db.collection("test_videos").path)
        - Database ID: \(db.app.options.projectID ?? "unknown")
        - Document ID to write: \(UUID().uuidString)
        """)
        
        // First update UI to show we're saving
        DispatchQueue.main.async {
            self.uploadStatus = .savingToFirestore(attempt: 1)
        }
        
        let video = Video(
            id: UUID().uuidString,
            videoUrl: downloadURL,
            caption: caption,
            createdAt: Date(),
            userId: Auth.auth().currentUser?.uid ?? "",
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
        
        print("""
        DEBUG: Attempting to write video data:
        \(videoData)
        """)
        
        // Write to test_videos collection
        let docRef = db.collection("test_videos").document(video.id)
        
        docRef.setData(videoData) { [weak self] error in
            print("""
            DEBUG: Write attempt details:
            - Collection: \(docRef.parent.path)
            - Document: \(docRef.documentID)
            - Full path: \(docRef.path)
            """)
            
            guard let self = self else {
                print("DEBUG: Self deallocated during write callback")
                return
            }
            
            // Verify the write immediately
            docRef.getDocument { [weak self] snapshot, verifyError in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    if let error = error ?? verifyError {
                        print("DEBUG: Write or verify failed: \(error.localizedDescription)")
                        self.handleError(error, completion: completion)
                        return
                    }
                    
                    guard let exists = snapshot?.exists, exists else {
                        print("DEBUG: Document verification failed - document doesn't exist")
                        self.handleError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Write verification failed"]), completion: completion)
                        return
                    }
                    
                    print("DEBUG: Document verified: \(snapshot?.data() ?? [:])")
                    
                    // Update all state at once
                    self.isUploading = false
                    self.uploadStatus = .completed
                    completion(.success(video))
                    
                    // Set uploadComplete last
                    print("DEBUG: Setting uploadComplete to trigger view dismissal")
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