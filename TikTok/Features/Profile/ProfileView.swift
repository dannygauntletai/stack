import SwiftUI
import FirebaseStorage
import Foundation

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @StateObject private var viewModel = ProfileViewModel()
    @StateObject private var feedViewModel = ShortFormFeedViewModel()
    @State private var selectedTab = 0
    @State private var showingMenu = false
    @State private var profileImageURL: URL?
    @State private var isLoadingProfileImage = false
    
    // Add these new properties
    private let imageCache = ImageCache.shared
    private let userDefaults = UserDefaults.standard
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Fixed Header
                VStack(spacing: 20) {
                    // Profile Image
                    if let url = profileImageURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 96, height: 96)
                                    .clipShape(Circle())
                            case .failure, .empty:
                                fallbackProfileImage
                            @unknown default:
                                fallbackProfileImage
                            }
                        }
                    } else {
                        fallbackProfileImage
                            .overlay {
                                if isLoadingProfileImage {
                                    ProgressView()
                                        .tint(.white)
                                }
                            }
                    }
                    
                    // Username
                    Text("@\(viewModel.user?.username ?? "username")")
                        .font(.headline)
                    
                    // Stats Row
                    HStack(spacing: 40) {
                        StatColumn(
                            count: "\(viewModel.user?.followingCount ?? 0)", 
                            title: "Following"
                        )
                        StatColumn(
                            count: "\(viewModel.user?.followersCount ?? 0)", 
                            title: "Followers"
                        )
                    }
                    
                    // Edit Profile Button
                    Button(action: {}) {
                        Text("Edit profile")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 160)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(2)
                    }
                }
                .padding(.vertical)
                
                // Tab Selector
                HStack(spacing: 0) {
                    ForEach(["Videos", "Liked"], id: \.self) { tab in
                        Button(action: {
                            withAnimation {
                                selectedTab = tab == "Videos" ? 0 : 1
                            }
                        }) {
                            VStack(spacing: 8) {
                                Text(tab)
                                    .foregroundColor(selectedTab == (tab == "Videos" ? 0 : 1) ? .white : .gray)
                                
                                // Indicator
                                Rectangle()
                                    .fill(selectedTab == (tab == "Videos" ? 0 : 1) ? .white : .clear)
                                    .frame(height: 2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                
                // Scrollable Content
                TabView(selection: $selectedTab) {
                    ScrollView {
                        PostsGridView(videos: viewModel.userVideos)
                            .padding(.top, 1)
                    }
                    .tag(0)
                    
                    ScrollView {
                        PostsGridView(videos: viewModel.likedVideos)
                            .padding(.top, 1)
                    }
                    .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        // Other menu items first
                        Button(action: {}) {
                            Label("Settings", systemImage: "gearshape")
                        }
                        
                        Button(action: {}) {
                            Label("Privacy", systemImage: "lock")
                        }
                        
                        // Logout at the bottom
                        Button(role: .destructive, action: {
                            authViewModel.signOut()
                        }) {
                            Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.white)
                            .font(.system(size: 20))
                    }
                }
            }
        }
        .environmentObject(feedViewModel)
        .task {
            // Load cached data first
            loadCachedData()
            // Then fetch fresh data
            await viewModel.fetchUserContent()
            await loadProfileImage()
        }
    }
    
    private func loadCachedData() {
        // Load cached username
        if let cachedUsername = userDefaults.string(forKey: "cached_username") {
            viewModel.setCachedUsername(cachedUsername)
        }
        
        // Load cached profile image
        if let cachedImageUrl = userDefaults.string(forKey: "cached_profile_image_url"),
           let url = URL(string: cachedImageUrl) {
            profileImageURL = url
            
            // Load cached image from disk if available
            if let cachedImage = imageCache.getImage(forKey: cachedImageUrl) {
                profileImageURL = URL(string: cachedImageUrl)
            }
        }
    }
    
    private func loadProfileImage() async {
        guard let profileImageUrlString = viewModel.user?.profileImageUrl else { return }
        
        // Cache the username if available
        if let username = viewModel.user?.username {
            userDefaults.set(username, forKey: "cached_username")
        }
        
        // If it's already a regular URL, use it directly
        if profileImageUrlString.hasPrefix("http") {
            profileImageURL = URL(string: profileImageUrlString)
            userDefaults.set(profileImageUrlString, forKey: "cached_profile_image_url")
            return
        }
        
        // Handle gs:// URLs
        guard profileImageUrlString.hasPrefix("gs://") else { return }
        
        isLoadingProfileImage = true
        defer { isLoadingProfileImage = false }
        
        do {
            let storage = Storage.storage()
            let storageRef = storage.reference(forURL: profileImageUrlString)
            
            // Get the download URL
            let downloadURL = try await storageRef.downloadURL()
            
            // Cache the download URL
            userDefaults.set(downloadURL.absoluteString, forKey: "cached_profile_image_url")
            
            // Download and cache the image
            let (data, _) = try await URLSession.shared.data(from: downloadURL)
            if let image = UIImage(data: data) {
                imageCache.setImage(image, forKey: downloadURL.absoluteString)
            }
            
            // Update the profile image URL on the main thread
            await MainActor.run {
                profileImageURL = downloadURL
            }
        } catch {
            print("Error loading profile image: \(error)")
        }
    }
    
    // New computed property for fallback profile image
    private var fallbackProfileImage: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 96, height: 96)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            )
    }
}

struct StatColumn: View {
    let count: String
    let title: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(count)
                .font(.system(size: 17, weight: .semibold))
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }
}

struct PostsGridView: View {
    let columns = [
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1)
    ]
    
    let videos: [Video]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 1) {
            ForEach(videos) { video in
                VideoThumbnail(video: video)
            }
        }
    }
}

struct VideoThumbnail: View {
    let video: Video
    @EnvironmentObject private var feedViewModel: ShortFormFeedViewModel
    @State private var showVideo = false
    @State private var thumbnailURL: URL?
    @State private var isLoadingThumbnail = false
    
    var body: some View {
        ZStack {
            if let url = thumbnailURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure(_):
                        placeholderView
                            .overlay {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.white)
                            }
                    case .empty:
                        placeholderView
                            .overlay {
                                ProgressView()
                                    .tint(.white)
                            }
                    @unknown default:
                        placeholderView
                    }
                }
            } else {
                placeholderView
                    .overlay {
                        if isLoadingThumbnail {
                            ProgressView()
                                .tint(.white)
                        }
                    }
            }
        }
        .frame(width: UIScreen.main.bounds.width / 3, height: UIScreen.main.bounds.width / 3)
        .clipped()
        .onTapGesture {
            showVideo = true
        }
        .task {
            await loadThumbnail()
        }
        .fullScreenCover(isPresented: $showVideo) {
            VideoPlayerView(video: video)
                .environmentObject(feedViewModel)
                .background(.clear)
                .presentationBackground(.clear)
        }
    }
    
    private func loadThumbnail() async {
        guard let thumbnailUrlString = video.thumbnailUrl else { return }
        
        // If it's already a regular URL, use it directly
        if thumbnailUrlString.hasPrefix("http") {
            thumbnailURL = URL(string: thumbnailUrlString)
            return
        }
        
        // Handle gs:// URLs
        guard thumbnailUrlString.hasPrefix("gs://") else { return }
        
        isLoadingThumbnail = true
        defer { isLoadingThumbnail = false }
        
        do {
            let storage = Storage.storage()
            let storageRef = storage.reference(forURL: thumbnailUrlString)
            
            // Get the download URL
            let downloadURL = try await storageRef.downloadURL()
            
            // Update the thumbnail URL on the main thread
            await MainActor.run {
                thumbnailURL = downloadURL
            }
        } catch {
            print("Error loading thumbnail for video \(video.id): \(error)")
        }
    }
    
    private var placeholderView: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay(
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                        Text("\(video.likes)")
                            .font(.system(size: 12))
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.bottom, 6)
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 0)
                }
            )
    }
}

// Add this new view for the full-screen video player
struct VideoPlayerView: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var feedViewModel: ShortFormFeedViewModel
    @State private var offset: CGSize = .zero
    @GestureState private var isDragging = false
    
    // Constants
    private let tabBarHeight: CGFloat = 49
    private let verticalDismissThreshold: CGFloat = 100
    private let horizontalDismissThreshold: CGFloat = 150
    
    // Computed properties for smooth transitions
    private var blurRadius: CGFloat {
        let maxRadius: CGFloat = 20.0
        let vertical = abs(offset.height) / CGFloat(300) * maxRadius
        let horizontal = abs(offset.width) / CGFloat(300) * maxRadius
        return min(max(vertical, horizontal), maxRadius)
    }
    
    private var scale: CGFloat {
        let minScale: CGFloat = 0.8
        let vertical = 1.0 - abs(offset.height) / CGFloat(1000)
        let horizontal = 1.0 - abs(offset.width) / CGFloat(1000)
        return max(min(vertical, horizontal), minScale)
    }
    
    private func dismissWithAnimation(in direction: DismissDirection) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            switch direction {
            case .right:
                offset.width = UIScreen.main.bounds.width
            case .left:
                offset.width = -UIScreen.main.bounds.width
            case .up:
                offset.height = -UIScreen.main.bounds.height
            case .down:
                offset.height = UIScreen.main.bounds.height
            }
        }
        dismiss()
    }
    
    private enum DismissDirection {
        case up, down, left, right
    }
    
    var body: some View {
        ZStack {
            // Main content
            ZStack(alignment: .top) {
                ShortFormVideoPlayer(
                    videoURL: URL(string: video.videoUrl)!,
                    visibility: VideoVisibility(
                        isFullyVisible: true,
                        isPartiallyVisible: true,
                        visibilityPercentage: 1.0
                    )
                )
                .ignoresSafeArea()
                
                GeometryReader { geometry in
                    ZStack(alignment: .top) {
                        // Close button
                        HStack {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    dismiss()
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(.black.opacity(0.3))
                                    .clipShape(Circle())
                            }
                            Spacer()
                        }
                        .padding(.top, 60)
                        .padding(.horizontal, 16)
                        
                        HomeVideoOverlay(video: video)
                            .frame(height: geometry.size.height - tabBarHeight)
                            .offset(y: geometry.safeAreaInsets.top)
                    }
                }
            }
            .scaleEffect(scale)
            .blur(radius: blurRadius)
        }
        .background(.clear)
        .offset(x: offset.width, y: offset.height)
        .gesture(
            DragGesture()
                .updating($isDragging) { value, state, _ in
                    state = true
                }
                .onChanged { value in
                    let translation = value.translation
                    offset = CGSize(
                        width: translation.width * 0.8,
                        height: translation.height * 0.8
                    )
                }
                .onEnded { value in
                    let translation = value.translation
                    let velocity = CGSize(
                        width: value.predictedEndLocation.x - value.location.x,
                        height: value.predictedEndLocation.y - value.location.y
                    )
                    
                    if abs(translation.height) > verticalDismissThreshold || abs(velocity.height) > 500 ||
                       abs(translation.width) > horizontalDismissThreshold || abs(velocity.width) > 500 {
                        
                        // Determine dismiss direction based on dominant axis and direction
                        if abs(translation.width) > abs(translation.height) {
                            dismissWithAnimation(in: translation.width > 0 ? .right : .left)
                        } else {
                            dismissWithAnimation(in: translation.height > 0 ? .down : .up)
                        }
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            offset = .zero
                        }
                    }
                }
        )
        .preferredColorScheme(.dark)
    }
}

// Add this class at the bottom of the file
final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    
    private init() {}
    
    func setImage(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
        
        // Also save to disk
        if let data = image.jpegData(compressionQuality: 0.8) {
            let filename = getFilename(from: key)
            let fileURL = getDocumentsDirectory().appendingPathComponent(filename)
            try? data.write(to: fileURL)
        }
    }
    
    func getImage(forKey key: String) -> UIImage? {
        // First check memory cache
        if let image = cache.object(forKey: key as NSString) {
            return image
        }
        
        // Then check disk cache
        let filename = getFilename(from: key)
        let fileURL = getDocumentsDirectory().appendingPathComponent(filename)
        if let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            // Store in memory cache for next time
            cache.setObject(image, forKey: key as NSString)
            return image
        }
        
        return nil
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func getFilename(from urlString: String) -> String {
        let hash = urlString.hash
        return "profile_image_\(abs(hash)).jpg"
    }
}

#Preview {
    ProfileView()
        .preferredColorScheme(.dark)
} 