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
            
            UploadView()
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