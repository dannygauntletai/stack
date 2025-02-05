import SwiftUI
import FirebaseFirestore
import FirebaseAuth

@MainActor
class StackViewModel: ObservableObject {
    @Published var categories: [StackCategory] = []
    @Published var stackCounts: [String: Int] = [:]
    private let db = Firestore.firestore()
    
    init() {
        fetchCategories()
        Task {
            await fetchStackCounts()
        }
    }
    
    func fetchCategories() {
        categories = StackCategory.categories
    }
    
    func fetchStackCounts() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("stacks")
                .getDocuments()
            
            var counts: [String: Int] = [:]
            for doc in snapshot.documents {
                if let categoryId = doc.data()["categoryId"] as? String {
                    counts[categoryId, default: 0] += 1
                }
            }
            
            for category in categories {
                stackCounts[category.id] = counts[category.id] ?? 0  // Use string ID
            }
        } catch {
            print("Error fetching stack counts: \(error)")
        }
    }
    
    func addVideoToStack(video: Video, categoryId: String) async {  // Changed from UUID to String
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            try await db.collection("users")
                .document(userId)
                .collection("stacks")
                .document(video.id)
                .setData([
                    "videoId": video.id,
                    "categoryId": categoryId,  // Use string ID directly
                    "addedAt": Timestamp(date: Date())
                ])
            
            await fetchStackCounts()
        } catch {
            print("Error adding to stack: \(error)")
        }
    }
} 