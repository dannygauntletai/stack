import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct StackedComponentsView: View {
    let category: StackCategory
    @State private var videos: [Video] = []
    private let db = Firestore.firestore()
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ScrollView {
            if videos.isEmpty {
                EmptyStateView(category: category)
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(videos) { video in
                        NavigationLink(destination: FeedView(initialVideo: video)) {
                            VideoCell(video: video, category: category)
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle(category.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Text("\(videos.count) videos")
                    .foregroundStyle(.gray)
                    .font(.subheadline)
            }
        }
        .task {
            fetchVideos()
        }
    }
    
    private func fetchVideos() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Query user's stacks collection for videos in this category
        db.collection("users")
            .document(userId)
            .collection("stacks")
            .whereField("categoryId", isEqualTo: category.id)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error fetching videos: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                // Get video IDs from stacks
                let videoIds = documents.compactMap { doc -> String? in
                    doc.data()["videoId"] as? String
                }
                
                // If no videos found, clear the list
                if videoIds.isEmpty {
                    self.videos = []
                    return
                }
                
                // Fetch actual video data from videos collection
                db.collection("videos")
                    .whereField("id", in: videoIds)
                    .getDocuments { (snapshot, error) in
                        if let error = error {
                            print("Error fetching video details: \(error)")
                            return
                        }
                        
                        self.videos = snapshot?.documents.compactMap { document in
                            let data = document.data()
                            return Video(
                                id: document.documentID,
                                videoUrl: data["videoUrl"] as? String ?? "",
                                caption: data["caption"] as? String ?? "",
                                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                                userId: data["userId"] as? String ?? "",
                                likes: data["likes"] as? Int ?? 0,
                                comments: data["comments"] as? Int ?? 0,
                                shares: data["shares"] as? Int ?? 0,
                                thumbnailUrl: data["thumbnailUrl"] as? String
                            )
                        } ?? []
                    }
            }
    }
}

// Separate view for video cell
struct VideoCell: View {
    let video: Video
    let category: StackCategory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: URL(string: video.thumbnailUrl ?? video.videoUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(category.color.opacity(0.1))
                    .overlay(
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(category.color)
                    )
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(video.caption)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                
                HStack(spacing: 12) {
                    Label("\(video.likes)", systemImage: "heart.fill")
                    Label("\(video.comments)", systemImage: "bubble.right.fill")
                }
                .font(.system(size: 12))
                .foregroundStyle(.gray)
                
                Text("Added \(timeAgoString(from: video.createdAt))")
                    .font(.system(size: 12))
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal, 4)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2, y: 1)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct EmptyStateView: View {
    let category: StackCategory
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: category.icon)
                .font(.system(size: 60))
                .foregroundStyle(category.color)
            
            Text("No videos in \(category.name) stack")
                .font(.headline)
            
            Text("Videos you add will appear here")
                .font(.subheadline)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    NavigationView {
        StackedComponentsView(category: StackCategory.categories[0])
    }
} 