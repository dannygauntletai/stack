import SwiftUI
import FirebaseFirestore
import FirebaseAuth

@MainActor
class StackViewModel: ObservableObject {
    @Published var categories: [StackCategory] = []
    @Published var stackCounts: [String: Int] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    private let db = Firestore.firestore()
    
    init() {
        Task {
            await fetchCategories()
            await fetchStackCounts()
        }
    }
    
    func fetchCategories() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("categories")
                .getDocuments()
            
            categories = snapshot.documents.compactMap { doc -> StackCategory? in
                guard let name = doc.data()["name"] as? String,
                      let icon = doc.data()["icon"] as? String,
                      let colorHex = doc.data()["color"] as? String else {
                    return nil
                }
                return StackCategory(id: doc.documentID,
                                   name: name,
                                   icon: icon,
                                   color: Color(hex: colorHex) ?? .gray)
            }
            
            // If no categories exist yet, create default ones
            if categories.isEmpty {
                await createDefaultCategories()
            }
        } catch {
            print("Error fetching categories: \(error)")
            errorMessage = "Failed to load categories"
        }
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
    
    func createCategory(name: String, icon: String, color: Color) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            let colorHex = color.toHex() ?? "#808080" // Default to gray if conversion fails
            
            let docRef = try await db.collection("users")
                .document(userId)
                .collection("categories")
                .addDocument(data: [
                    "name": name,
                    "icon": icon,
                    "color": colorHex,
                    "createdAt": Timestamp(date: Date())
                ])
            
            // Add the new category to the local array
            let newCategory = StackCategory(id: docRef.documentID,
                                          name: name,
                                          icon: icon,
                                          color: color)
            categories.append(newCategory)
        } catch {
            print("Error creating category: \(error)")
            throw error
        }
    }
    
    private func createDefaultCategories() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        for category in StackCategory.defaultCategories {
            do {
                let colorHex = category.color.toHex() ?? "#808080"
                try await db.collection("users")
                    .document(userId)
                    .collection("categories")
                    .document(category.id)
                    .setData([
                        "name": category.name,
                        "icon": category.icon,
                        "color": colorHex,
                        "createdAt": Timestamp(date: Date())
                    ])
            } catch {
                print("Error creating default category \(category.name): \(error)")
            }
        }
        
        // Fetch categories again to update the local array
        await fetchCategories()
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