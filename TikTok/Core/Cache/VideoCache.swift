import Foundation
import AVFoundation

/// Thread-safe LRU cache for video assets
final class VideoCache {
    // MARK: - Types
    private final class CacheEntry {
        let asset: AVURLAsset
        var lastAccessTime: Date
        
        init(asset: AVURLAsset) {
            self.asset = asset
            self.lastAccessTime = Date()
        }
        
        func updateAccessTime() {
            lastAccessTime = Date()
        }
    }
    
    // MARK: - Properties
    static let shared = VideoCache()
    
    private let cache: NSCache<NSURL, CacheEntry>
    private let queue = DispatchQueue(label: "com.app.videocache", attributes: .concurrent)
    private let fileManager = FileManager.default
    private var cacheDirectory: URL
    
    /// Maximum number of videos to keep in memory
    private let maxCacheEntries = 10
    /// Maximum cache size in bytes (500MB)
    private let maxCacheSize: UInt64 = 500 * 1024 * 1024
    
    private var entries: [NSURL: CacheEntry] = [:]
    
    // MARK: - Initialization
    private init() {
        cache = NSCache<NSURL, CacheEntry>()
        cache.countLimit = maxCacheEntries
        
        // Set up cache directory
        let cacheURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = cacheURL.appendingPathComponent("VideoCache", isDirectory: true)
        
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Clean up old cache files
        cleanDiskCache()
    }
    
    // MARK: - Public Methods
    func getVideo(for url: URL) async throws -> AVURLAsset {
        if let cachedAsset = getCachedAsset(for: url as NSURL) {
            return cachedAsset
        }
        
        return try await downloadAndCacheVideo(from: url)
    }
    
    func clearCache() {
        queue.async(flags: .barrier) {
            self.cache.removeAllObjects()
            self.entries.removeAll()
            try? self.fileManager.removeItem(at: self.cacheDirectory)
            try? self.fileManager.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Private Methods
    private func getCachedAsset(for url: NSURL) -> AVURLAsset? {
        queue.sync {
            if let entry = cache.object(forKey: url) {
                entry.updateAccessTime()
                return entry.asset
            }
            return nil
        }
    }
    
    private func downloadAndCacheVideo(from url: URL) async throws -> AVURLAsset {
        let destinationURL = cacheDirectory.appendingPathComponent(url.lastPathComponent)
        
        // Check if already downloaded
        if fileManager.fileExists(atPath: destinationURL.path) {
            let asset = AVURLAsset(url: destinationURL)
            cacheAsset(asset, for: url as NSURL)
            return asset
        }
        
        // Download video
        let (downloadURL, _) = try await URLSession.shared.download(from: url)
        
        // Move to cache directory
        try? fileManager.removeItem(at: destinationURL)
        try fileManager.moveItem(at: downloadURL, to: destinationURL)
        
        // Create and cache asset
        let asset = AVURLAsset(url: destinationURL)
        cacheAsset(asset, for: url as NSURL)
        
        // Clean up if needed
        await cleanCacheIfNeeded()
        
        return asset
    }
    
    private func cacheAsset(_ asset: AVURLAsset, for url: NSURL) {
        queue.async(flags: .barrier) {
            let entry = CacheEntry(asset: asset)
            self.cache.setObject(entry, forKey: url)
            self.entries[url] = entry
        }
    }
    
    private func cleanCacheIfNeeded() async {
        queue.async(flags: .barrier) {
            // Remove oldest entries if we exceed count limit
            while self.entries.count > self.maxCacheEntries {
                guard let oldestEntry = self.entries.min(by: { $0.value.lastAccessTime < $1.value.lastAccessTime }) else { break }
                self.entries.removeValue(forKey: oldestEntry.key)
                self.cache.removeObject(forKey: oldestEntry.key)
            }
        }
        
        await cleanDiskCache()
    }
    
    private func cleanDiskCache() {
        queue.async {
            let resourceKeys: [URLResourceKey] = [.creationDateKey, .fileSizeKey]
            guard let fileEnumerator = FileManager.default.enumerator(
                at: self.cacheDirectory,
                includingPropertiesForKeys: resourceKeys
            ) else { return }
            
            var totalSize: UInt64 = 0
            var cacheFiles: [(url: URL, date: Date, size: UInt64)] = []
            
            // Collect file information
            for case let fileURL as URL in fileEnumerator {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
                      let creationDate = resourceValues.creationDate,
                      let fileSize = resourceValues.fileSize else { continue }
                
                totalSize += UInt64(fileSize)
                cacheFiles.append((fileURL, creationDate, UInt64(fileSize)))
            }
            
            // Sort by date (oldest first)
            cacheFiles.sort { $0.date < $1.date }
            
            // Remove old files until we're under size limit
            while totalSize > self.maxCacheSize, let oldestFile = cacheFiles.first {
                try? FileManager.default.removeItem(at: oldestFile.url)
                totalSize -= oldestFile.size
                cacheFiles.removeFirst()
            }
        }
    }
} 