import Foundation

/// 채팅 답변 출처의 종류 (Phase 8.8): 종합 위키 페이지 vs 개별 메모(정리본).
nonisolated enum ChatReferenceKind: String, Sendable {
    case wiki
    case memo
}

/// 채팅 답변에 인용된 출처 1개(위키 또는 메모). 메시지에는 `token`으로 직렬화된다.
nonisolated struct ChatReference: Sendable, Identifiable, Hashable {
    let kind: ChatReferenceKind
    /// wikiId 또는 sourceId.
    let id: String
    let title: String
    let score: Float

    /// 메시지 저장용 토큰. 예: "wiki:UUID" / "memo:UUID".
    var token: String { "\(kind.rawValue):\(id)" }
}

struct ChatResponse: Sendable {
    let answer: String
    /// 위키/메모가 섞인 출처 목록(관련도 순, 위키 우선).
    let references: [ChatReference]
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
