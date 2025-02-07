import Foundation

public struct HealthAnalysis: Codable {
    public let longevityImpact: String
    public let summary: String
    public let risks: [String]
    public let contentType: String
    public let recommendations: [String]
    public let benefits: [String]
    
    public enum CodingKeys: String, CodingKey {
        case longevityImpact = "longevity_impact"
        case summary
        case risks
        case contentType = "content_type"
        case recommendations
        case benefits
    }
} 