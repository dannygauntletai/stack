import SwiftUI

struct HomeView: View {
    @State private var selectedTab = 0
    
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
                    .tag(0)
                    .ignoresSafeArea()
                
                Text("Following Feed")
                    .foregroundColor(.white)
                    .tag(1)
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
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
} 