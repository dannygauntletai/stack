import Foundation

enum UploadStatus: Equatable {
    case ready
    case uploading(progress: Double)
    case processingURL
    case savingToFirestore(attempt: Int = 1)
    case completed
    case error(String)
    
    var message: String {
        switch self {
        case .ready:
            return "Ready to upload"
        case .uploading(let progress):
            return "Uploading: \(Int(progress * 100))%"
        case .processingURL:
            return "Processing video..."
        case .savingToFirestore(let attempt):
            return "Finalizing... (Attempt \(attempt)/3)"
        case .completed:
            return "Upload completed!"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    var isError: Bool {
        if case .error(_) = self { return true }
        return false
    }
} 