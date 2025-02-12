import Foundation
import FirebaseFirestore

struct Price: Codable {
    let amount: Double
    let currency: String
    let displayAmount: String
    
    enum CodingKeys: String, CodingKey {
        case amount
        case currency
        case displayAmount = "displayAmount"
        case display_amount = "display_amount"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        amount = try container.decode(Double.self, forKey: .amount)
        currency = try container.decode(String.self, forKey: .currency)
        
        if let displayAmt = try? container.decode(String.self, forKey: .displayAmount) {
            displayAmount = displayAmt
        } else {
            displayAmount = try container.decode(String.self, forKey: .display_amount)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(amount, forKey: .amount)
        try container.encode(currency, forKey: .currency)
        try container.encode(displayAmount, forKey: .displayAmount) // Store in Firestore format
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "amount": amount,
            "currency": currency,
            "displayAmount": displayAmount
        ]
    }
}

struct ProductCategory: Identifiable, Codable {
    var id: String
    let name: String
    let icon: String
    let userId: String
    let createdAt: Date
    
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
    
    enum CodingKeys: String, CodingKey {
        case id
        case categoryId
        case userId
        case asin
        case title
        case imageUrl
        case price
        case productUrl
        case createdAt
    }
    
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

struct Product: Codable {
    let asin: String
    let title: String
    let imageUrl: String
    let price: Price
    let rating: Double?
    let reviewCount: Int?
    let productUrl: String
    let isPrime: Bool
    
    enum CodingKeys: String, CodingKey {
        case asin
        case title
        case imageUrl = "image_url"
        case price
        case rating
        case reviewCount = "review_count"
        case productUrl = "product_url"
        case isPrime = "is_prime"
    }
}