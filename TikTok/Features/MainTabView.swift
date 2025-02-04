import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            FeedView()
                .tabItem {
                    Image(systemName: "house")
                        .environment(\.symbolVariants, .none)
                    Text("Home")
                }
                .tag(0)
            
            Text("Upload") // Placeholder for upload view
                .tabItem {
                    Image(systemName: "plus.square")
                        .environment(\.symbolVariants, .none)
                    Text("Upload")
                }
                .tag(1)
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person")
                        .environment(\.symbolVariants, .none)
                    Text("Profile")
                }
                .tag(2)
        }
        .tint(.white)
        .onAppear {
            // Set white color for tab items
            UITabBar.appearance().unselectedItemTintColor = .white
            UITabBar.appearance().tintColor = .white
            
            // Hide tab bar when in feed
            let tabBarAppearance = UITabBarAppearance()
            if selectedTab == 0 {
                tabBarAppearance.configureWithTransparentBackground()
            } else {
                tabBarAppearance.configureWithDefaultBackground()
            }
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
            UITabBar.appearance().standardAppearance = tabBarAppearance
        }
    }
}

// Add ProfileView with logout functionality
private struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Profile")
                    .font(.title)
                    .padding()
                
                Button(action: {
                    authViewModel.signOut()
                }) {
                    Text("Sign Out")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("Profile")
        }
    }
} 