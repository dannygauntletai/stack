import Foundation
import FirebaseFirestore

struct ProductCategory: Identifiable, Codable {
    var id: String  // Regular property instead of @DocumentID
    let name: String
    let icon: String
    let userId: String
    let createdAt: Date  // Regular property instead of @ServerTimestamp
    
    var dictionary: [String: Any] {
        return [
            "id": id,
            "name": name,
            "icon": icon,
            "userId": userId,
            "createdAt": createdAt
        ]
    }
}

struct SavedProduct: Identifiable, Codable {
    var id: String
    let categoryId: String
    let userId: String
    let asin: String
    let title: String
    let imageUrl: String
    let price: Price
    let productUrl: String
    let createdAt: Date
    
    var dictionary: [String: Any] {
        return [
            "id": id,
            "categoryId": categoryId,
            "userId": userId,
            "asin": asin,
            "title": title,
            "imageUrl": imageUrl,
            "price": price.toDictionary(),
            "productUrl": productUrl,
            "createdAt": createdAt
        ]
    }
} 