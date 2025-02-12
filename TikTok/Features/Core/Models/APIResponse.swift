struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let report: T?
} 