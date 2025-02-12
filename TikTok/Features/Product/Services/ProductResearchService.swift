import Foundation

class ProductResearchService {
    static let shared = ProductResearchService()
    private let baseURL = AppEnvironment.baseURL
    
    struct ProductRequest: Codable {
        let id: String
        let title: String
        let asin: String
        let price: Price
        let productUrl: String
        
        init(from product: SavedProduct) {
            self.id = product.id
            self.title = product.title
            self.asin = product.asin
            self.price = product.price
            self.productUrl = product.productUrl
        }
    }
    
    func startResearch(products: [SavedProduct]) async throws -> String {
        let url = URL(string: "\(baseURL)/research/compare-products")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Convert to proper encodable type
        let productsData = products.map(ProductRequest.init)
        let body = try JSONEncoder().encode(productsData)
        request.httpBody = body
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ResearchResponse.self, from: data)
        
        return response.research_id
    }
    
    func checkStatus(researchId: String) async throws -> ResearchStatusResponse {
        let url = URL(string: "\(baseURL)/research/status/\(researchId)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(ResearchStatusResponse.self, from: data)
    }
}

// Response models
struct ResearchResponse: Codable {
    let success: Bool
    let research_id: String
    let status: String
    let timestamp: String
}

struct ResearchStatusResponse: Codable {
    let success: Bool
    let research_id: String
    let status: ResearchStatusData
}

struct ResearchStatusData: Codable {
    let status: String
    let results: ResearchResults?
    let error: String?
    let updated_at: String
} 