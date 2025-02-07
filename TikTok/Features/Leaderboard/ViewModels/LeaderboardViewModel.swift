import Foundation
import Firebase
import FirebaseFirestore

struct LeaderboardUser: Identifiable {
    let id: String
    let username: String
    let profileImageUrl: String?
    let totalHealthImpact: Double
}

class LeaderboardViewModel: ObservableObject {
    @Published var leaderboardUsers: [LeaderboardUser] = []
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    
    func fetchLeaderboardData() {
        isLoading = true
        
        // First, get all users
        db.collection("users").getDocuments { [weak self] userSnapshot, userError in
            guard let self = self else { return }
            
            if let userError = userError {
                print("Error fetching users: \(userError)")
                self.isLoading = false
                return
            }
            
            guard let users = userSnapshot?.documents else {
                self.isLoading = false
                return
            }
            
            // Create a dispatch group to handle async operations
            let group = DispatchGroup()
            var leaderboardEntries: [(user: [String: Any], score: Double)] = []
            
            for userDoc in users {
                group.enter()
                let userData = userDoc.data()
                
                // Fetch user's stacks and sum up the healthImpactScore directly from the stack documents
                self.db.collection("users")
                    .document(userDoc.documentID)
                    .collection("stacks")
                    .getDocuments { stackSnapshot, stackError in
                        defer { group.leave() }
                        
                        if let stackError = stackError {
                            print("Error fetching stacks: \(stackError)")
                            return
                        }
                        
                        let totalScore = stackSnapshot?.documents.reduce(0.0) { sum, stackDoc in
                            sum + (stackDoc.data()["healthImpactScore"] as? Double ?? 0)
                        } ?? 0
                        
                        leaderboardEntries.append((userData, totalScore))
                    }
            }
            
            group.notify(queue: .main) {
                // Sort users by total health impact score
                let sortedEntries = leaderboardEntries.sorted { $0.score > $1.score }
                
                // Convert to LeaderboardUser objects
                self.leaderboardUsers = sortedEntries.map { entry in
                    LeaderboardUser(
                        id: entry.user["uid"] as? String ?? "",
                        username: entry.user["username"] as? String ?? "Unknown",
                        profileImageUrl: entry.user["profileImageUrl"] as? String,
                        totalHealthImpact: entry.score
                    )
                }
                
                self.isLoading = false
            }
        }
    }
} 