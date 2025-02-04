import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthenticationViewModel()
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                MainTabView()
                    .environmentObject(authViewModel)
                    .transition(.opacity.animation(.easeInOut))
            } else {
                LoginView()
                    .environmentObject(authViewModel)
                    .transition(.opacity.animation(.easeInOut))
            }
        }
        .background(Color.black) // TikTok uses pure black background
    }
}

// Add preview for development
#Preview {
    ContentView()
} 