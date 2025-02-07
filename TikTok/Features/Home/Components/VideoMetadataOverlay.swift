import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct VideoMetadataOverlay: View {
    let author: VideoAuthor
    let caption: String?
    let tags: [String]
    @State private var isFollowing = false
    @State private var isLoading = false
    @State private var isOwnVideo = false
    
    private let tiktokBlue = Color(red: 76/255, green: 176/255, blue: 249/255)
    private let db = Firestore.firestore()
    
    private func checkFollowStatus() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { 
            isOwnVideo = false
            isFollowing = false
            return 
        }
        
        // Check if it's the user's own video
        isOwnVideo = currentUserId == author.id
        
        // Reset following state
        isFollowing = false
        
        // If not own video, check follow status
        if !isOwnVideo {
            db.collection("followers")
                .document(author.id)
                .collection("userFollowers")
                .document(currentUserId)
                .getDocument { document, error in
                    DispatchQueue.main.async {
                        isFollowing = document?.exists ?? false
                    }
                }
        }
    }
    
    private func handleFollowAction() {
        guard !isLoading,
              let currentUserId = Auth.auth().currentUser?.uid,
              currentUserId != author.id else { return }
        
        isLoading = true
        
        let batch = db.batch()
        
        // References for both collections
        let followerRef = db.collection("followers")
            .document(author.id)
            .collection("userFollowers")
            .document(currentUserId)
        
        let followingRef = db.collection("following")
            .document(currentUserId)
            .collection("userFollowing")
            .document(author.id)
        
        if isFollowing {
            // Unfollow: Delete from both collections
            batch.deleteDocument(followerRef)
            batch.deleteDocument(followingRef)
        } else {
            // Follow: Add to both collections with timestamps
            let timestamp = Timestamp()
            let followData: [String: Any] = ["timestamp": timestamp]
            
            batch.setData(followData, forDocument: followerRef)
            batch.setData(followData, forDocument: followingRef)
        }
        
        // Commit the batch
        batch.commit { error in
            DispatchQueue.main.async {
                isLoading = false
                if error == nil {
                    isFollowing.toggle()
                }
            }
        }
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
                    VStack(alignment: .leading, spacing: 4) {
                        if let caption = caption, !caption.isEmpty {
                            Text(caption)
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .frame(maxWidth: geometry.size.width * 0.75, alignment: .leading)
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                                .padding(.top, 2)
                        } else {
                            Text("No description provided")
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.7))
                                .italic()
                                .lineLimit(1)
                                .frame(maxWidth: geometry.size.width * 0.75, alignment: .leading)
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                                .padding(.top, 2)
                        }
                        
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
                                                    .fill(Color.black.opacity(0.25))
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
            .onAppear {
                checkFollowStatus()
            }
        }
    }
} 