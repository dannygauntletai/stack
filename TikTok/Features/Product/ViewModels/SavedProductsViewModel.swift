import Foundation
import FirebaseFirestore
import FirebaseAuth

class SavedProductsViewModel: ObservableObject {
    @Published private(set) var products: [SavedProduct] = []
    @Published private(set) var isLoading = false
    private let db = Firestore.firestore()
    
    func fetchProducts(categoryId: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { 
            print("⚠️ No user ID found")
            return 
        }
        
        print("📱 Fetching products for category: \(categoryId)")
        await MainActor.run { isLoading = true }
        
        do {
            db.collection("users")
                .document(userId)
                .collection("productCategories")
                .document(categoryId)
                .collection("products")
                .order(by: "createdAt", descending: true)
                .addSnapshotListener { [weak self] snapshot, error in
                    if let error = error {
                        print("❌ Error fetching products: \(error)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        print("⚠️ No documents found")
                        return
                    }
                    
                    print("📦 Found \(documents.count) products")
                    
                    // Debug the document data
                    documents.forEach { doc in
                        print("🔍 Document ID: \(doc.documentID)")
                        print("📄 Data: \(doc.data())")
                    }
                    
                    self?.products = documents.compactMap { document in
                        do {
                            let product = try document.data(as: SavedProduct.self)
                            return product
                        } catch {
                            print("❌ Failed to parse document: \(error)")
                            print("📄 Failed document data: \(document.data())")
                            return nil
                        }
                    }
                    
                    print("✅ Parsed \(self?.products.count ?? 0) products")
                    self?.isLoading = false
                }
        } catch {
            print("❌ Error setting up listener: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    // Optional: Add method to remove products
    func removeProduct(_ product: SavedProduct, from categoryId: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            try await db.collection("users")
                .document(userId)
                .collection("productCategories")
                .document(categoryId)
                .collection("products")
                .document(product.id)
                .delete()
        } catch {
            print("Error removing product: \(error)")
        }
    }
} 