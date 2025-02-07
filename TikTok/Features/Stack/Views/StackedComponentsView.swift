import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct StackedComponentsView: View {
    let category: StackCategory
    @StateObject private var viewModel = StackedComponentsViewModel()
    @State private var selectedVideo: Video? = nil
    @State private var showHealthAnalysis = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 100)
            } else if viewModel.videos.isEmpty {
                EmptyStateView(category: category)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(viewModel.videos) { video in
                        NavigationLink(
                            destination: HealthAnalysisView(
                                video: video,
                                viewModel: viewModel,
                                isPresented: $showHealthAnalysis
                            )
                        ) {
                            ThumbnailCard(
                                video: video,
                                category: category,
                                viewModel: viewModel
                            )
                        }
                        .buttonStyle(ThumbnailButtonStyle())
                    }
                }
                .padding(.horizontal, 12)
            }
        }
        .background(Color.black)
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchVideos(for: category.id)
        }
        .refreshable {
            await viewModel.fetchVideos(for: category.id)
        }
    }
}

private struct ThumbnailCard: View {
    let video: Video
    let category: StackCategory
    @ObservedObject var viewModel: StackedComponentsViewModel
    
    private let size = (UIScreen.main.bounds.width - 32) / 2
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Thumbnail
            Group {
                if let thumbnailUrl = video.thumbnailUrl {
                    StorageImageView(gsURL: thumbnailUrl) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        thumbnailPlaceholder
                    }
                } else {
                    thumbnailPlaceholder
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Health Impact Score indicator
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 12))
                Text(healthImpactText)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(healthImpactColor)
            .padding(8)
            .background(.black.opacity(0.3))
            .cornerRadius(8)
            .padding(4)
        }
    }
    
    private var healthImpactText: String {
        if let healthImpactScore = viewModel.healthImpactScore(for: video.id) {
            return "\(Int(healthImpactScore))"
        }
        return "..."
    }
    
    private var healthImpactColor: Color {
        guard let score = viewModel.healthImpactScore(for: video.id) else { return .gray }
        switch score {
        case ..<0: return .red
        case 0..<3: return .orange
        case 3..<7: return .yellow
        default: return .green
        }
    }
    
    private var thumbnailPlaceholder: some View {
        Rectangle()
            .fill(category.color.opacity(0.1))
            .overlay {
                Image(systemName: "play.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(category.color)
            }
    }
}

private struct ThumbnailButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

private struct EmptyStateView: View {
    let category: StackCategory
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: category.icon)
                .font(.system(size: 60))
                .foregroundStyle(category.color)
            
            Text("No videos in this stack yet")
                .font(.headline)
            
            Text("Videos you add to this category will appear here")
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

@MainActor
final class StackedComponentsViewModel: ObservableObject {
    @Published private(set) var videos: [Video] = []
    @Published private(set) var isLoading = false
    @Published private var healthData: [String: HealthAnalysis] = [:]
    @Published private var healthImpactScores: [String: Double] = [:]
    
    private let db = Firestore.firestore()
    
    func healthImpactScore(for videoId: String) -> Double? {
        return healthImpactScores[videoId]
    }
    
    // Now this can be public too since HealthAnalysis is public
    func healthAnalysis(for videoId: String) -> HealthAnalysis? {
        return healthData[videoId]
    }
    
    func fetchVideos(for categoryId: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Get video IDs from user's stacks for this category
            let stacksRef = db.collection("users")
                .document(userId)
                .collection("stacks")
                .whereField("categoryId", isEqualTo: categoryId)
            
            let stacksSnapshot = try await stacksRef.getDocuments()
            let videoIds = stacksSnapshot.documents.compactMap { $0.data()["videoId"] as? String }
            
            guard !videoIds.isEmpty else {
                self.videos = []
                return
            }
            
            // Fetch videos
            let videosRef = db.collection("videos")
                .whereField(FieldPath.documentID(), in: videoIds)
            
            let videosSnapshot = try await videosRef.getDocuments()
            self.videos = videosSnapshot.documents.compactMap { doc in
                let data = doc.data()
                
                // Parse health analysis data
                if let healthAnalysisData = data["healthAnalysis"] as? [String: Any] {
                    print("Raw health analysis data for video \(doc.documentID):")
                    print(healthAnalysisData)
                    
                    if let healthAnalysisJson = try? JSONSerialization.data(withJSONObject: healthAnalysisData) {
                        do {
                            let healthAnalysis = try JSONDecoder().decode(HealthAnalysis.self, from: healthAnalysisJson)
                            print("Successfully parsed health analysis:")
                            print("Content type: \(healthAnalysis.contentType)")
                            print("Summary: \(healthAnalysis.summary)")
                            print("Benefits count: \(healthAnalysis.benefits.count)")
                            healthData[doc.documentID] = healthAnalysis
                        } catch {
                            print("Failed to decode health analysis: \(error)")
                        }
                    }
                }
                
                // Store the health impact score
                if let score = data["healthImpactScore"] as? Double {
                    print("Health Impact Score for video \(doc.documentID): \(score)")
                    healthImpactScores[doc.documentID] = score
                }
                
                return Video(
                    id: doc.documentID,
                    videoUrl: data["videoUrl"] as? String ?? "",
                    caption: data["caption"] as? String ?? "",
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                    userId: data["userId"] as? String ?? "",
                    author: VideoAuthor(
                        id: data["userId"] as? String ?? "",
                        username: data["username"] as? String ?? "Unknown User",
                        profileImageUrl: data["profileImageUrl"] as? String
                    ),
                    likes: data["likes"] as? Int ?? 0,
                    comments: data["comments"] as? Int ?? 0,
                    shares: data["shares"] as? Int ?? 0,
                    thumbnailUrl: data["thumbnailUrl"] as? String
                )
            }
            
        } catch {
            print("Error fetching stacked videos: \(error)")
            self.videos = []
        }
    }
}

#Preview {
    NavigationView {
        StackedComponentsView(category: StackCategory(id: "1", name: "Favorites", icon: "star.fill", color: .yellow))
    }
} 