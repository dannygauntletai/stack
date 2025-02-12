import Foundation
import FirebaseFirestore
import FirebaseAuth

class SavedProductsViewModel: ObservableObject {
    @Published private(set) var products: [SavedProduct] = []
    private let db = Firestore.firestore()
    
    func fetchProducts(categoryId: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("productCategories")
                .document(categoryId)
                .collection("products")
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            let products = snapshot.documents.compactMap { document in
                try? document.data(as: SavedProduct.self)
            }
            
            await MainActor.run {
                self.products = products
            }
        } catch {
            print("Error fetching products: \(error)")
        }
    }
} 