import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthenticationViewModel
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
                        PostsGridView()
                            .padding(.top, 1)
                    }
                    .tag(0)
                    
                    ScrollView {
                        PostsGridView()
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
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 1) {
            ForEach(0..<15) { _ in
                Color.gray.opacity(0.3)
                    .aspectRatio(1, contentMode: .fill)
                    .overlay(
                        VStack {
                            Spacer()
                            HStack {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 12))
                                Text("1.2K")
                                    .font(.system(size: 12))
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding(.bottom, 6)
                            .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 0)
                        }
                    )
                    .clipped()
            }
        }
    }
}

#Preview {
    ProfileView()
        .preferredColorScheme(.dark)
} 