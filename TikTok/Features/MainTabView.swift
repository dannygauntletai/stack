import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            FeedView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("Home")
                }
                .tag(0)
            
            Text("Upload")
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "plus.square.fill" : "plus.square")
                    Text("Upload")
                }
                .tag(1)
            
            ProfileView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "person.fill" : "person")
                    Text("Profile")
                }
                .tag(2)
        }
        .tint(.white)
        .onAppear {
            // Set white color for tab items
            UITabBar.appearance().unselectedItemTintColor = .white.withAlphaComponent(0.7)
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