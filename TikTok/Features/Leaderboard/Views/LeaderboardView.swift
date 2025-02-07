import SwiftUI
import Firebase

struct LeaderboardView: View {
    @StateObject private var viewModel = LeaderboardViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(Array(viewModel.leaderboardUsers.enumerated()), id: \.element.id) { index, user in
                                LeaderboardRowView(rank: index + 1, user: user)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            viewModel.fetchLeaderboardData()
        }
    }
}

struct LeaderboardRowView: View {
    let rank: Int
    let user: LeaderboardUser
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 30)
            
            if let imageUrl = user.profileImageUrl {
                StorageImageView(gsURL: imageUrl) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.username)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(impactText)
                    .font(.system(size: 14))
                    .foregroundColor(impactColor)
            }
            
            Spacer()
            
            if rank <= 3 {
                Image(systemName: "trophy.fill")
                    .foregroundColor(rank == 1 ? .yellow : rank == 2 ? .gray : .brown)
                    .font(.system(size: 20))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var impactText: String {
        let impact = Int(user.totalHealthImpact)
        if impact > 0 {
            return "+\(impact) minutes gained"
        } else if impact < 0 {
            return "\(impact) minutes lost"
        } else {
            return "Neutral impact"
        }
    }
    
    private var impactColor: Color {
        if user.totalHealthImpact > 0 {
            return .green
        } else if user.totalHealthImpact < 0 {
            return .red
        } else {
            return .gray
        }
    }
} 