import Foundation
import FirebaseAuth

class UserInteractionService {
    static let shared = UserInteractionService()
    private let defaults = UserDefaults.standard
    private let graph = RecommendationGraph()
    
    // Keys for UserDefaults
    enum Keys: String {
        case videoWatchTime = "video_watch_time"
        case videoLikes = "video_likes"
        case videoComments = "video_comments"
        case videoStacks = "video_stacks"
        case videoSkips = "video_skips"
        case userId = "current_user_id"
    }
    
    private init() {
        // Initialize default values if needed
        if defaults.object(forKey: Keys.videoWatchTime.rawValue) == nil {
            defaults.set([String: Double](), forKey: Keys.videoWatchTime.rawValue)
        }
        if defaults.object(forKey: Keys.videoLikes.rawValue) == nil {
            defaults.set([String: Bool](), forKey: Keys.videoLikes.rawValue)
        }
        if defaults.object(forKey: Keys.videoComments.rawValue) == nil {
            defaults.set([String: Int](), forKey: Keys.videoComments.rawValue)
        }
        if defaults.object(forKey: Keys.videoStacks.rawValue) == nil {
            defaults.set([String: Bool](), forKey: Keys.videoStacks.rawValue)
        }
        if defaults.object(forKey: Keys.videoSkips.rawValue) == nil {
            defaults.set([String: Bool](), forKey: Keys.videoSkips.rawValue)
        }
    }
    
    // Track video watch time
    func trackWatchTime(videoId: String, duration: Double) {
        var watchTimes = defaults.object(forKey: Keys.videoWatchTime.rawValue) as? [String: Double] ?? [:]
        watchTimes[videoId] = (watchTimes[videoId] ?? 0) + duration
        defaults.set(watchTimes, forKey: Keys.videoWatchTime.rawValue)
        printCurrentCache(action: "Watch Time", videoId: videoId, data: watchTimes)
        updateAndPrintGraph()
    }
    
    // Track video like
    func trackLike(videoId: String, isLiked: Bool) {
        var likes = defaults.object(forKey: Keys.videoLikes.rawValue) as? [String: Bool] ?? [:]
        likes[videoId] = isLiked
        defaults.set(likes, forKey: Keys.videoLikes.rawValue)
        printCurrentCache(action: "Like", videoId: videoId, data: likes)
        updateAndPrintGraph()
    }
    
    // Track video comment
    func trackComment(videoId: String) {
        var comments = defaults.object(forKey: Keys.videoComments.rawValue) as? [String: Int] ?? [:]
        comments[videoId] = (comments[videoId] ?? 0) + 1
        defaults.set(comments, forKey: Keys.videoComments.rawValue)
        printCurrentCache(action: "Comment", videoId: videoId, data: comments)
        updateAndPrintGraph()
    }
    
    // Track video stack
    func trackStack(videoId: String) {
        var stacks = defaults.object(forKey: Keys.videoStacks.rawValue) as? [String: Bool] ?? [:]
        stacks[videoId] = true
        defaults.set(stacks, forKey: Keys.videoStacks.rawValue)
        printCurrentCache(action: "Stack", videoId: videoId, data: stacks)
        updateAndPrintGraph()
    }
    
    // Track video skip
    func trackSkip(videoId: String) {
        var skips = defaults.object(forKey: Keys.videoSkips.rawValue) as? [String: Bool] ?? [:]
        skips[videoId] = true
        defaults.set(skips, forKey: Keys.videoSkips.rawValue)
        printCurrentCache(action: "Skip", videoId: videoId, data: skips)
        updateAndPrintGraph()
    }
    
    // Debug helper to print current cache state
    private func printCurrentCache<T>(action: String, videoId: String, data: [String: T]) {
        print("\n=== User Interaction Cache: \(action) ===")
        print("Video ID: \(videoId)")
        print("Current \(action) Data:", data)
        print("All Interaction Data for video:", getInteractionData(for: videoId))
        print("=====================================\n")
    }
    
    // Get interaction data for a video
    func getInteractionData(for videoId: String) -> VideoInteraction {
        let watchTimes = defaults.object(forKey: Keys.videoWatchTime.rawValue) as? [String: Double] ?? [:]
        let likes = defaults.object(forKey: Keys.videoLikes.rawValue) as? [String: Bool] ?? [:]
        let comments = defaults.object(forKey: Keys.videoComments.rawValue) as? [String: Int] ?? [:]
        let stacks = defaults.object(forKey: Keys.videoStacks.rawValue) as? [String: Bool] ?? [:]
        let skips = defaults.object(forKey: Keys.videoSkips.rawValue) as? [String: Bool] ?? [:]
        let userId = defaults.string(forKey: Keys.userId.rawValue)
        
        return VideoInteraction(
            watchTime: watchTimes[videoId] ?? 0,
            isLiked: likes[videoId] ?? false,
            commentCount: comments[videoId] ?? 0,
            isStacked: stacks[videoId] ?? false,
            isSkipped: skips[videoId] ?? false,
            userId: userId
        )
    }
    
    // Clear all interaction data
    func clearAllData() {
        defaults.removeObject(forKey: Keys.videoWatchTime.rawValue)
        defaults.removeObject(forKey: Keys.videoLikes.rawValue)
        defaults.removeObject(forKey: Keys.videoComments.rawValue)
        defaults.removeObject(forKey: Keys.videoStacks.rawValue)
        defaults.removeObject(forKey: Keys.videoSkips.rawValue)
        defaults.removeObject(forKey: Keys.userId.rawValue)
    }
    
    // Get all interactions for recommendation graph
    func getAllInteractions() -> (
        watchTimes: [String: Double],
        likes: [String: Bool],
        comments: [String: Int],
        stacks: [String: Bool],
        skips: [String: Bool]
    ) {
        let watchTimes = defaults.object(forKey: Keys.videoWatchTime.rawValue) as? [String: Double] ?? [:]
        let likes = defaults.object(forKey: Keys.videoLikes.rawValue) as? [String: Bool] ?? [:]
        let comments = defaults.object(forKey: Keys.videoComments.rawValue) as? [String: Int] ?? [:]
        let stacks = defaults.object(forKey: Keys.videoStacks.rawValue) as? [String: Bool] ?? [:]
        let skips = defaults.object(forKey: Keys.videoSkips.rawValue) as? [String: Bool] ?? [:]
        
        print("\n=== All User Interactions ===")
        print("Watch Times:", watchTimes)
        print("Likes:", likes)
        print("Comments:", comments)
        print("Stacks:", stacks)
        print("Skips:", skips)
        print("===========================\n")
        
        return (watchTimes, likes, comments, stacks, skips)
    }
    
    // Update user ID when auth state changes
    func updateUserId(_ userId: String?) {
        defaults.set(userId, forKey: Keys.userId.rawValue)
    }
    
    // Update and print graph after each interaction
    private func updateAndPrintGraph() {
        Task {
            if let userId = defaults.string(forKey: Keys.userId.rawValue) {
                print("\n=== Updating Recommendation Graph ===")
                await graph.buildGraph(forUserId: userId)
            }
        }
    }
} 