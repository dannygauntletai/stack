import SwiftUI

struct HomeView: View {
    @State private var selectedTab = 0
    @StateObject private var forYouViewModel = ShortFormFeedViewModel(isFollowingFeed: false)
    @StateObject private var followingViewModel = ShortFormFeedViewModel(isFollowingFeed: true)
    
    private var topInset: CGFloat {
        // Get the window scene's safe area insets
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let window = windowScene?.windows.first
        return window?.safeAreaInsets.top ?? 47
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Full screen black background
            Color.black.ignoresSafeArea()
            
            // Content
            TabView(selection: $selectedTab) {
                ShortFormFeed(initialVideo: nil)
                    .environmentObject(forYouViewModel)
                    .tag(0)
                    .ignoresSafeArea()
                    .onChange(of: selectedTab) { newValue in
                        if newValue == 0 {
                            forYouViewModel.reset()
                        }
                    }
                
                ShortFormFeed(initialVideo: nil)
                    .environmentObject(followingViewModel)
                    .tag(1)
                    .ignoresSafeArea()
                    .onChange(of: selectedTab) { newValue in
                        if newValue == 1 {
                            followingViewModel.reset()
                        }
                    }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            
            // Tab selector
            HStack(spacing: 20) {
                ForEach(["For You", "Following"], id: \.self) { tab in
                    Button(action: {
                        withAnimation {
                            selectedTab = tab == "For You" ? 0 : 1
                        }
                    }) {
                        VStack(spacing: 8) {
                            Text(tab)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(selectedTab == (tab == "For You" ? 0 : 1) ? .white : .white.opacity(0.6))
                            
                            // Indicator
                            Rectangle()
                                .fill(selectedTab == (tab == "For You" ? 0 : 1) ? .white : .clear)
                                .frame(height: 2)
                                .frame(width: 30)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [.black.opacity(0.3), .clear]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .padding(.top, topInset)
        }
        .ignoresSafeArea()
        .onAppear {
            // Load initial feed
            forYouViewModel.loadVideos()
        }
        .onReceive(NotificationCenter.default.publisher(for: .followStatusChanged)) { _ in
            if selectedTab == 1 {  // If on Following tab
                followingViewModel.refreshFeed()
            }
        }
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}

// Add notification name
extension Notification.Name {
    static let followStatusChanged = Notification.Name("followStatusChanged")
} 