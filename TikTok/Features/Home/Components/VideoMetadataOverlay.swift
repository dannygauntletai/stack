import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct VideoMetadataOverlay: View {
    let author: VideoAuthor
    let caption: String?
    let videoId: String
    @State private var tags: [String] = []
    @State private var isFollowing = false
    @State private var isLoading = false
    @State private var isOwnVideo = false
    @State private var hasLoadedTags = false
    
    init(author: VideoAuthor, caption: String?, videoId: String) {
        self.author = author
        self.caption = caption
        self.videoId = videoId
    }
    
    private let tiktokBlue = Color(red: 76/255, green: 176/255, blue: 249/255)
    private let db = Firestore.firestore()
    
    // Add UserDefaults cache for following status
    private let followCache = UserDefaults.standard
    private var followCacheKey: String {
        "following_\(author.id)"
    }
    
    private func checkFollowStatus() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { 
            isOwnVideo = false
            isFollowing = false
            return 
        }
        
        // Check if it's the user's own video
        isOwnVideo = currentUserId == author.id
        
        if isOwnVideo {
            isFollowing = false
            return
        }
        
        // First check cache for immediate UI update
        isFollowing = followCache.bool(forKey: followCacheKey)
        
        // Then verify with server
        db.collection("users")
            .document(currentUserId)
            .collection("following")
            .document(author.id)
            .getDocument { document, error in
                DispatchQueue.main.async {
                    let serverStatus = document?.exists ?? false
                    // Only update UI if different from cache
                    if serverStatus != isFollowing {
                        isFollowing = serverStatus
                        // Update cache with server value
                        self.followCache.set(serverStatus, forKey: self.followCacheKey)
                    }
                }
            }
    }
    
    private func handleFollowAction() {
        guard !isLoading,
              let currentUserId = Auth.auth().currentUser?.uid,
              currentUserId != author.id else { return }
        
        isLoading = true
        
        // Optimistically update UI and cache
        let newFollowStatus = !isFollowing
        isFollowing = newFollowStatus
        followCache.set(newFollowStatus, forKey: followCacheKey)
        
        let batch = db.batch()
        
        let followerRef = db.collection("users")
            .document(author.id)
            .collection("followers")
            .document(currentUserId)
        
        let followingRef = db.collection("users")
            .document(currentUserId)
            .collection("following")
            .document(author.id)
        
        if newFollowStatus {
            // Follow
            let timestamp = Timestamp()
            let followData: [String: Any] = ["timestamp": timestamp]
            batch.setData(followData, forDocument: followerRef)
            batch.setData(followData, forDocument: followingRef)
        } else {
            // Unfollow
            batch.deleteDocument(followerRef)
            batch.deleteDocument(followingRef)
        }
        
        // Commit the batch
        batch.commit { error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    // Revert on error
                    print("Error updating follow status: \(error)")
                    isFollowing = !newFollowStatus
                    self.followCache.set(!newFollowStatus, forKey: self.followCacheKey)
                } else {
                    // Success - notify any following feed to refresh
                    NotificationCenter.default.post(name: .followStatusChanged, object: nil)
                }
            }
        }
    }
    
    private func fetchVideoTags() {
        db.collection("videos")
            .document(videoId)
            .getDocument { document, error in
                if let healthAnalysisData = document?.get("healthAnalysis") as? [String: Any] {
                    if let rawTags = healthAnalysisData["tags"] as? [String] {
                        let cleanedTags = rawTags.map { tag in
                            tag.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
                        }
                        DispatchQueue.main.async {
                            self.tags = cleanedTags
                            self.hasLoadedTags = true
                        }
                    }
                }
            }
    }
    
    private func colorForTag(_ tag: String) -> Color {
        // Define a set of pleasant colors
        let colors: [Color] = [
            .blue.opacity(0.8),
            .green.opacity(0.8),
            .purple.opacity(0.8),
            .orange.opacity(0.8),
            .pink.opacity(0.8),
            .teal.opacity(0.8)
        ]
        
        // Use the hash of the tag string to consistently pick a color
        let hash = abs(tag.hashValue)
        let index = hash % colors.count
        
        return colors[index]
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                
                VStack(alignment: .leading, spacing: -20) {
                    // Username and profile section
                    HStack(alignment: .top, spacing: 10) {
                        // Profile image
                        if let imageUrl = author.profileImageUrl {
                            AsyncImage(url: URL(string: imageUrl)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .padding(.top, 2)
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .foregroundColor(.gray)
                                .frame(width: 40, height: 40)
                                .padding(.top, 2)
                        }
                        
                        Text("@\(author.username)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                            .padding(.top, 2)
                        
                        // Follow button - show only if not own video
                        if !isOwnVideo {
                            Button {
                                handleFollowAction()
                            } label: {
                                Text(isFollowing ? "Following" : "Follow")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(isFollowing ? .gray : .white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(isFollowing ? Color.white : Color.black.opacity(0.75))
                                    )
                            }
                            .disabled(isLoading)
                            .opacity(isLoading ? 0.5 : 1)
                        }
                    }
                    .padding(.top, 24)
                    
                    // Caption and tags container
                    VStack(alignment: .leading, spacing: 8) {
                        // Caption
                        if let caption = caption, !caption.isEmpty {
                            Text(caption)
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .frame(maxWidth: geometry.size.width * 0.75, alignment: .leading)
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        } else {
                            Text("No description provided")
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.7))
                                .italic()
                                .lineLimit(1)
                                .frame(maxWidth: geometry.size.width * 0.75, alignment: .leading)
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        }
                        
                        // Tags
                        if !tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 4)
                                            .background(
                                                Capsule()
                                                    .fill(colorForTag(tag).opacity(0.75))
                                            )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.leading, 50)
                }
                
                Spacer()
                    .frame(height: 120)
            }
            .padding(.horizontal, 16)
            .onChange(of: author.id) { _, _ in
                checkFollowStatus()
            }
            .onChange(of: videoId) { _, _ in
                fetchVideoTags()
            }
            .onAppear {
                checkFollowStatus()
                fetchVideoTags()
            }
        }
    }
} 