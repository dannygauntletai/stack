import Foundation
import FirebaseFirestore

/// Represents a node in the recommendation graph
enum GraphNode: Hashable {
    case user(String)      // userId
    case video(String)     // videoId
    case tag(String)       // tag name (can be health-related, exercise type, etc)
    case category(String)  // stack category id
    
    var id: String {
        switch self {
        case .user(let id): return "u_\(id)"
        case .video(let id): return "v_\(id)"
        case .tag(let tag): return "t_\(tag)"
        case .category(let id): return "c_\(id)"
        }
    }
}

/// Represents an edge type in the recommendation graph
enum EdgeType: String {
    // User -> Video interactions
    case watched = "WATCHED"          
    case liked = "LIKED"             
    case commented = "COMMENTED"      
    case stacked = "STACKED"         
    case skipped = "SKIPPED"         
    
    // Video -> Category/Tag relationships
    case belongsTo = "BELONGS_TO"    
    case hasTag = "HAS_TAG"          
    
    // TODO: These weights should be determined by:
    // 1. Analysis of user engagement patterns
    // 2. A/B testing different weight configurations
    // 3. Machine learning to optimize weights
    // For now using placeholder weights that will need tuning
    var weight: Double {
        switch self {
        case .watched: return 1.0     // Base weight, should be adjusted by watch duration
        case .liked: return 1.0       // Strong signal of interest
        case .commented: return 1.0    // Strong engagement signal
        case .stacked: return 1.0     // Explicit save for later
        case .skipped: return -0.5    // Negative signal
        case .belongsTo: return 0.8   // User-defined categorization
        case .hasTag: return 0.5      // Content similarity signal
        }
    }
}

/// Represents a weighted edge in the graph
struct Edge: Hashable {
    let source: GraphNode
    let target: GraphNode
    let type: EdgeType
    let weight: Double
    let timestamp: Date
    
    init(source: GraphNode, target: GraphNode, type: EdgeType, timestamp: Date) {
        self.source = source
        self.target = target
        self.type = type
        self.weight = type.weight
        self.timestamp = timestamp
    }
}

/// Main recommendation graph structure
class RecommendationGraph {
    private var nodes: Set<GraphNode> = []
    private var edges: [GraphNode: Set<Edge>] = [:]
    private let db = Firestore.firestore()
    
    /// Build graph from user interaction data
    func buildGraph(forUserId userId: String) async {
        // Clear existing graph
        nodes.removeAll()
        edges.removeAll()
        
        // Add user node
        let userNode = GraphNode.user(userId)
        nodes.insert(userNode)
        
        // First get user's interaction videos
        let interactions = UserInteractionService.shared.getAllInteractions()
        let (watchTimes, likes, comments, stacks, skips) = interactions
        
        // Get pool of potential videos (e.g., recent, trending, or similar to user's interests)
        let potentialVideos = try? await db.collection("videos")
            .whereField("createdAt", isGreaterThan: Date().addingTimeInterval(-7*24*60*60)) // Last 7 days
            .limit(to: 100)  // Reasonable pool size
            .getDocuments()
        
        // Combine interacted videos with potential videos
        let interactedVideoIds = Set(watchTimes.keys)
            .union(likes.keys)
            .union(comments.keys)
            .union(stacks.keys)
            .union(skips.keys)
        
        var allVideoIds = interactedVideoIds
        potentialVideos?.documents.forEach { doc in
            allVideoIds.insert(doc.documentID)
        }
        
        print("\n=== Building Recommendation Graph ===")
        print("User Node:", userNode)
        print("Found \(interactedVideoIds.count) interacted videos")
        print("Added \(allVideoIds.count - interactedVideoIds.count) potential videos")

        // Add video nodes and interaction edges
        for videoId in allVideoIds {
            let videoNode = GraphNode.video(videoId)
            nodes.insert(videoNode)
            
            print("\nProcessing Video:", videoId)
            
            // Add edges based on interactions (only for interacted videos)
            if interactedVideoIds.contains(videoId) {
                if watchTimes[videoId] != nil {
                    addEdge(Edge(source: userNode, target: videoNode, type: .watched, timestamp: Date()))
                    print("- Added watch edge")
                }
                if likes[videoId] == true {
                    addEdge(Edge(source: userNode, target: videoNode, type: .liked, timestamp: Date()))
                    print("- Added like edge")
                }
                if comments[videoId] != nil {
                    addEdge(Edge(source: userNode, target: videoNode, type: .commented, timestamp: Date()))
                    print("- Added comment edge")
                }
                if stacks[videoId] == true {
                    addEdge(Edge(source: userNode, target: videoNode, type: .stacked, timestamp: Date()))
                    print("- Added stack edge")
                }
                if skips[videoId] == true {
                    addEdge(Edge(source: userNode, target: videoNode, type: .skipped, timestamp: Date()))
                    print("- Added skip edge")
                }
            }
            
            await addVideoMetadata(videoId: videoId, videoNode: videoNode, userId: userId)
        }
        
        print("\nFinal Graph Stats:")
        print("Total Nodes:", nodes.count)
        print("Total Edges:", edges.values.map { $0.count }.reduce(0, +))
        print("==============================\n")
        
        // Print the graph structure after building
        printGraph()
    }
    
    private func addVideoMetadata(videoId: String, videoNode: GraphNode, userId: String) async {
        do {
            let videoDoc = try await db.collection("videos").document(videoId).getDocument()
            guard let data = videoDoc.data() else { return }
            
            // Add tags from health analysis
            if let healthAnalysis = data["healthAnalysis"] as? [String: Any] {
                // Handle different types of tags
                if let tags = healthAnalysis["tags"] as? [String] {
                    for tag in tags {
                        let tagNode = GraphNode.tag(tag)
                        nodes.insert(tagNode)
                        addEdge(Edge(source: videoNode, target: tagNode, type: .hasTag, timestamp: Date()))
                    }
                }
                
                // Could add other types of tags/metadata:
                // - contentType
                // - benefits
                // - risks
                // - recommendations
            }
            
            // Get categories from user's stacks instead of video metadata
            let stacksRef = db.collection("users")
                .document(userId)
                .collection("stacks")
                .whereField("videoId", isEqualTo: videoId)
            
            let stacksSnapshot = try await stacksRef.getDocuments()
            for doc in stacksSnapshot.documents {
                if let categoryId = doc.data()["categoryId"] as? String {
                    let categoryNode = GraphNode.category(categoryId)
                    nodes.insert(categoryNode)
                    addEdge(Edge(source: videoNode, target: categoryNode, type: .belongsTo, timestamp: Date()))
                }
            }
        } catch {
            print("Error fetching video metadata: \(error)")
        }
    }
    
    private func addEdge(_ edge: Edge) {
        edges[edge.source, default: []].insert(edge)
    }
    
    /// Get neighboring nodes with weights for random walk
    func getNeighbors(of node: GraphNode) -> [(node: GraphNode, weight: Double)] {
        guard let nodeEdges = edges[node] else { return [] }
        return nodeEdges.map { edge in
            (node: edge.target, weight: edge.weight)
        }
    }
    
    // Print graph structure
    private func printGraph() {
        print("\n=== Recommendation Graph Structure ===")
        print("Total Nodes:", nodes.count)
        
        // Print nodes by type
        let userNodes = nodes.filter { if case .user(_) = $0 { return true } else { return false }}
        let videoNodes = nodes.filter { if case .video(_) = $0 { return true } else { return false }}
        let tagNodes = nodes.filter { if case .tag(_) = $0 { return true } else { return false }}
        let categoryNodes = nodes.filter { if case .category(_) = $0 { return true } else { return false }}
        
        print("\nNodes by type:")
        print("Users (\(userNodes.count)):", userNodes.map { $0.id })
        print("Videos (\(videoNodes.count)):", videoNodes.map { $0.id })
        print("Tags (\(tagNodes.count)):", tagNodes.map { $0.id })
        print("Categories (\(categoryNodes.count)):", categoryNodes.map { $0.id })
        
        print("\nAdjacency List:")
        for node in nodes {
            print("\n\(node.id) ->")
            if let nodeEdges = edges[node] {
                for edge in nodeEdges {
                    print("  ├─ [\(edge.type.rawValue)] -> \(edge.target.id) (weight: \(edge.weight))")
                }
            }
        }
        print("\n===============================")
    }
    
    /// Performs a random walk on the graph starting from a given node
    /// - Parameters:
    ///   - startNode: The node to start the walk from
    ///   - steps: Number of steps to take
    ///   - alpha: Probability of restarting walk from start node (teleport factor)
    ///   - maxVisitsPerNode: Maximum times a node can be visited
    /// - Returns: Array of nodes visited during the walk
    func randomWalk(
        from startNode: GraphNode,
        steps: Int,
        alpha: Double = 0.15,
        maxVisitsPerNode: Int = 3
    ) -> [GraphNode] {
        var walk = [startNode]
        var currentNode = startNode
        var visitCounts: [GraphNode: Int] = [startNode: 1]
        
        for _ in 0..<steps {
            // Possibly teleport back to start node
            if Double.random(in: 0...1) < alpha {
                currentNode = startNode
                continue
            }
            
            // Get neighbors and their weights
            let neighbors = getNeighbors(of: currentNode)
            
            // If no valid neighbors, teleport to start
            guard !neighbors.isEmpty else {
                currentNode = startNode
                continue
            }
            
            // Filter out over-visited nodes
            let validNeighbors = neighbors.filter { neighbor in
                visitCounts[neighbor.node, default: 0] < maxVisitsPerNode
            }
            
            guard !validNeighbors.isEmpty else {
                currentNode = startNode
                continue
            }
            
            // Calculate transition probabilities
            let totalWeight = validNeighbors.reduce(0.0) { $0 + max(0, $1.weight) }
            var probabilities = validNeighbors.map { max(0, $0.weight) / totalWeight }
            
            // Choose next node based on weights
            let random = Double.random(in: 0...1)
            var cumulativeProb = 0.0
            
            for (index, prob) in probabilities.enumerated() {
                cumulativeProb += prob
                if random <= cumulativeProb {
                    currentNode = validNeighbors[index].node
                    visitCounts[currentNode, default: 0] += 1
                    walk.append(currentNode)
                    break
                }
            }
        }
        
        return walk
    }
    
    /// Get video recommendations for a user
    /// - Parameters:
    ///   - userId: User to get recommendations for
    ///   - count: Number of recommendations to return
    /// - Returns: Array of recommended video IDs
    func getRecommendations(forUser userId: String, count: Int) async -> [String] {
        let userNode = GraphNode.user(userId)
        
        // Perform multiple random walks
        let walks = randomWalk(from: userNode, steps: count * 3)
        
        // Extract video nodes from walks
        let videoNodes = walks.compactMap { node -> String? in
            if case .video(let videoId) = node {
                return videoId
            }
            return nil
        }
        
        // Count video occurrences to rank them
        var videoFrequency: [String: Int] = [:]
        videoNodes.forEach { videoFrequency[$0, default: 0] += 1 }
        
        // Sort by frequency and return top recommendations
        let recommendations = videoFrequency.sorted { $0.value > $1.value }
            .prefix(count)
            .map { $0.key }
        
        print("\n=== Recommendations for user \(userId) ===")
        print("Random walks found \(videoNodes.count) video nodes")
        print("Top recommendations:", recommendations)
        print("=====================================\n")
        
        return Array(recommendations)
    }
} 