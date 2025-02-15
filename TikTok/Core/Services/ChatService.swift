import Foundation

class ChatService {
    static let shared = ChatService()
    private var submittedFeedback: Set<String> = []
    private var messageRunIds: [String: String] = [:]
    
    func hasFeedbackBeenSubmitted(for messageId: String) -> Bool {
        return submittedFeedback.contains(messageId)
    }
    
    func markFeedbackSubmitted(for messageId: String) {
        submittedFeedback.insert(messageId)
    }
    
    func setRunId(_ runId: String, for messageId: String) {
        messageRunIds[messageId] = runId
    }
    
    func getRunId(for messageId: String) -> String? {
        return messageRunIds[messageId]
    }
    
    func submitPositiveFeedback(messageId: String, runId: String) async throws -> (success: Bool, error: String?) {
        print("🔄 Making positive feedback request for message: \(messageId)")
        print("🔑 Using run ID: \(runId)")
        
        let url = URL(string: "\(AppEnvironment.baseURL)/agents/feedback/\(runId)/thumbs-up")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid response type")
            return (false, "Invalid response")
        }
        
        if (200...299).contains(httpResponse.statusCode) {
            print("✅ Feedback submitted successfully")
            return (true, nil)
        } else {
            print("❌ Server error: \(httpResponse.statusCode)")
            return (false, "Server error: \(httpResponse.statusCode)")
        }
    }
    
    func submitNegativeFeedback(
        messageId: String, runId: String,
        comment: String? = nil
    ) async throws -> (success: Bool, error: String?) {
        let url = URL(string: "\(AppEnvironment.baseURL)/agents/feedback/\(runId)/thumbs-down")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let comment = comment {
            let body = ["comment": comment]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            return (false, "Invalid response")
        }
        
        if (200...299).contains(httpResponse.statusCode) {
            return (true, nil)
        } else {
            return (false, "Server error: \(httpResponse.statusCode)")
        }
    }
} 