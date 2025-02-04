import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @StateObject private var viewModel = ProfileViewModel()
    @State private var selectedTab = 0
    @State private var showingMenu = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Fixed Header
                VStack(spacing: 20) {
                    // Profile Image
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 96, height: 96)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        )
                    
                    // Username
                    Text("@username")
                        .font(.headline)
                    
                    // Stats Row
                    HStack(spacing: 40) {
                        StatColumn(count: "42", title: "Following")
                        StatColumn(count: "8.2K", title: "Followers")
                        StatColumn(count: "102K", title: "Likes")
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
        .task {
            await viewModel.fetchUserContent()
        }
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
    @State private var showVideo = false
    @State private var thumbnailURL: URL?
    
    var body: some View {
        ZStack {
            if let url = thumbnailURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .onAppear { print("DEBUG: Successfully loaded thumbnail for video \(video.id)") }
                    case .failure(let error):
                        placeholderView
                            .overlay {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.white)
                            }
                            .onAppear {
                                print("DEBUG: Failed to load thumbnail for video \(video.id)")
                                print("DEBUG: Error: \(error.localizedDescription)")
                                print("DEBUG: URL attempted: \(url.absoluteString)")
                            }
                    case .empty:
                        placeholderView
                            .overlay {
                                ProgressView()
                                    .tint(.white)
                            }
                            .onAppear { print("DEBUG: Loading thumbnail for video \(video.id)") }
                    @unknown default:
                        placeholderView
                    }
                }
            } else {
                placeholderView
                    .onAppear {
                        print("DEBUG: No thumbnail URL for video \(video.id)")
                        print("DEBUG: Raw thumbnailUrl value: \(String(describing: video.thumbnailUrl))")
                    }
            }
        }
        .frame(width: UIScreen.main.bounds.width / 3, height: UIScreen.main.bounds.width / 3)
        .clipped()
        .onTapGesture {
            showVideo = true
        }
        .onAppear {
            print("DEBUG: VideoThumbnail appeared for video \(video.id)")
            if let urlString = video.thumbnailUrl {
                print("DEBUG: Found URL string: \(urlString)")
                if let url = URL(string: urlString) {
                    print("DEBUG: Successfully created URL: \(url.absoluteString)")
                    self.thumbnailURL = url
                } else {
                    print("DEBUG: Failed to create URL from string: \(urlString)")
                }
            } else {
                print("DEBUG: No thumbnailUrl found for video \(video.id)")
            }
        }
        .fullScreenCover(isPresented: $showVideo) {
            NavigationStack {
                FeedView(
                    initialVideo: video,
                    isDeepLinked: true,
                    onBack: { showVideo = false }
                )
                .navigationBarHidden(true)
                .ignoresSafeArea()
            }
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

#Preview {
    ProfileView()
        .preferredColorScheme(.dark)
} 