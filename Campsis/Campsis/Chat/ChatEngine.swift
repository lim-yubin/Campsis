import Foundation

struct ChatResponse: Sendable {
    let answer: String
    let sources: [SearchResult]
}

protocol ChatEngineProtocol: Sendable {
    func send(query: String, conversationId: String) async throws -> ChatResponse
    func sendStream(query: String, conversationId: String,
                    onToken: @Sendable @escaping (String) -> Void) async throws -> ChatResponse
    func suggestTitle(for query: String, answer: String) async -> String?
    func resetSession() async
}

extension ChatEngineProtocol {
    func sendStream(query: String, conversationId: String,
                    onToken: @Sendable @escaping (String) -> Void) async throws -> ChatResponse {
        let response = try await send(query: query, conversationId: conversationId)
        onToken(response.answer)
        return response
    }

    func suggestTitle(for query: String, answer: String) async -> String? { nil }
}
