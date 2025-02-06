import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("Home")
                }
                .tag(0)
            
            // Moved Stacks to second position
            StackCategoriesView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "square.stack.3d.up.fill" : "square.stack.3d.up")
                    Text("Stacks")
                }
                .tag(1)
            
            UploadView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "plus.square.fill" : "plus.square")
                    Text("Upload")
                }
                .tag(2)
            
            // Added Leaderboard tab
            Text("Leaderboard View")
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "trophy.fill" : "trophy")
                    Text("Leaderboard")
                }
                .tag(3)
            
            ProfileView()
                .tabItem {
                    Image(systemName: selectedTab == 4 ? "person.fill" : "person")
                    Text("Profile")
                }
                .tag(4)
        }
        .tint(.white)
        .onAppear {
            // Set white color for unselected items
            UITabBar.appearance().unselectedItemTintColor = .white.withAlphaComponent(0.5)
            UITabBar.appearance().tintColor = .white
            
            // Configure tab bar appearance
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithTransparentBackground()
            
            // Set colors for text and icons
            tabBarAppearance.stackedLayoutAppearance.normal.iconColor = .white.withAlphaComponent(0.5)
            tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white.withAlphaComponent(0.5)]
            tabBarAppearance.stackedLayoutAppearance.selected.iconColor = .white
            tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white]
            
            UITabBar.appearance().standardAppearance = tabBarAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
    }
}