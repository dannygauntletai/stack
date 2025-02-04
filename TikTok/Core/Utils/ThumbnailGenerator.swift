import AVFoundation
import UIKit

enum ThumbnailError: Error {
    case invalidURL
    case assetError
    case generationError
}

class ThumbnailGenerator {
    static func generateThumbnail(from localURL: URL) async throws -> UIImage {
        print("DEBUG: Generating thumbnail from local video at: \(localURL)")
        
        let asset = AVAsset(url: localURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        // Generate thumbnail from the first frame
        let time = CMTime(seconds: 0, preferredTimescale: 1)
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            print("DEBUG: Thumbnail generated successfully")
            return UIImage(cgImage: cgImage)
        } catch {
            print("DEBUG: Thumbnail generation error: \(error.localizedDescription)")
            throw ThumbnailError.generationError
        }
    }
} 