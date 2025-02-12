import Foundation

struct ProductReport: Codable, Identifiable {
    let id: String
    let productId: String
    let productTitle: String
    let productUrl: String
    let research: ResearchSummary
    let timestamp: Date
    
    struct ResearchSummary: Codable {
        let summary: String
        let keyPoints: [String]
        let pros: [String]
        let cons: [String]
        let sources: [String]
    }
} 