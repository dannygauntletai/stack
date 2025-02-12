import Foundation
import FirebaseFirestore
import FirebaseAuth

class ProductCategoryViewModel: ObservableObject {
    @Published private(set) var categories: [ProductCategory] = []
    @Published private(set) var productCounts: [String: Int] = [:]
    private let db = Firestore.firestore()
    
    init() {
        fetchCategories()
    }
    
    private func fetchCategories() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users")
            .document(userId)
            .collection("productCategories")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self,
                      let documents = snapshot?.documents else { return }
                
                self.categories = documents.compactMap { document in
                    try? document.data(as: ProductCategory.self)
                }
            }
    }
    
    func fetchProductCounts() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            var counts: [String: Int] = [:]
            
            for category in categories {
                let snapshot = try await db.collection("users")
                    .document(userId)
                    .collection("productCategories")
                    .document(category.id)
                    .collection("products")
                    .getDocuments()
                
                counts[category.id] = snapshot.documents.count
            }
            
            await MainActor.run {
                self.productCounts = counts
            }
        } catch {
            print("Error fetching product counts: \(error)")
        }
    }
    
    func addProductToCategory(product: Product, categoryId: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let savedProduct = SavedProduct(
                id: UUID().uuidString,
                categoryId: categoryId,
                userId: userId,
                asin: product.asin,
                title: product.title,
                imageUrl: product.imageUrl,
                price: product.price,
                productUrl: product.productUrl,
                createdAt: Date()
            )
            
            try await db.collection("users")
                .document(userId)
                .collection("productCategories")
                .document(categoryId)
                .collection("products")
                .document(savedProduct.id)
                .setData(savedProduct.dictionary)
            
        } catch {
            print("Error saving product: \(error)")
        }
    }
    
    func createCategory(name: String, icon: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let category = ProductCategory(
            id: UUID().uuidString,
            name: name,
            icon: icon,
            userId: userId,
            createdAt: Date()
        )
        
        do {
            try await db.collection("users")
                .document(userId)
                .collection("productCategories")
                .document(category.id)
                .setData(category.dictionary)
        } catch {
            print("Error creating category: \(error)")
        }
    }
} 