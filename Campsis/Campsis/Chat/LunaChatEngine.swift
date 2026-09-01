import Foundation

/// GPT-5.6 Luna(OpenAI Chat Completions)를 사용하는 클라우드 생성 엔진 (D36, D38).
///
/// 검색(bge-m3 로컬)·컨텍스트 조립·인용은 로컬에서 수행하고, "답변 생성"만
/// OpenAI로 위임한다. 요청 시점에 관련 메모 조각 + 최근 대화만 전송되며,
/// 전체 데이터베이스/벡터는 전송하지 않는다.
///
/// 세션 상태를 들고 있지 않다. 매 요청마다 대화 이력을 저장소에서 재구성한다.
actor LunaChatEngine: ChatEngineProtocol {
    private let searchEngine: VectorSearchEngine
    private let messageRepository: MessageRepository
    private let apiKey: String
    private let model: String
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let maxContextChars = 12000
    private let historyLimit = 6

    private let instructions = """
        You are a personal AI assistant with access to the user's saved memories \
        (text clips, screenshots, notes, files). You also have general knowledge.

        Rules:
        1. If relevant sources (memories) are provided, base your answer primarily on them. \
           Do NOT insert bracketed source numbers like [1] or [2] in your answer — \
           the app shows the source list separately below the message.
        2. Judge whether the provided sources ACTUALLY help answer THIS specific question. \
           Similarity alone is not relevance. If the sources do not genuinely help (or none are provided), \
           you MUST begin your answer with this exact line on its own: \
           💡 메모리에 관련 정보가 없어 일반 지식으로 답변합니다. \
           Then answer from general knowledge. Never omit this line when the memories are unrelated to the question.
        3. If sources are partially relevant, combine memory-based info with general knowledge, \
           clearly distinguishing which parts come from memories vs general knowledge.
        4. Match the language of the user's question (Korean question → Korean answer).
        5. Default to a natural, conversational reply in plain prose. \
           Use markdown structure (headings, bullets, tables, numbered steps, bold) ONLY when the \
           content genuinely benefits from it — e.g. comparisons, multi-item lists, step-by-step \
           instructions, or tabular data. Do NOT structure short or conversational answers, and do \
           NOT add headings just to organize a brief reply. Do NOT wrap the entire answer in a code block.
        6. Be concise but helpful. Support follow-up questions using the conversation context.
        """

    init(searchEngine: VectorSearchEngine,
         messageRepository: MessageRepository,
         apiKey: String,
         model: String = "gpt-5.6-luna") {
        self.searchEngine = searchEngine
        self.messageRepository = messageRepository
        self.apiKey = apiKey
        self.model = model
    }

    func send(query: String, conversationId: String) async throws -> ChatResponse {
        let results = Self.relevantSources(from: try await searchEngine.search(query: query, topN: 5))
        let messages = try buildMessages(query: query, conversationId: conversationId, results: results)
        let answer = try await completeChat(messages: messages)
        let cleaned = Self.stripCitations(answer)
        return ChatResponse(answer: cleaned, sources: Self.sources(for: cleaned, from: results))
    }

    func sendStream(query: String, conversationId: String,
                    onToken: @Sendable @escaping (String) -> Void) async throws -> ChatResponse {
        let results = Self.relevantSources(from: try await searchEngine.search(query: query, topN: 5))
        let messages = try buildMessages(query: query, conversationId: conversationId, results: results)

        let answer = try await streamChat(messages: messages, onToken: onToken)
        let cleaned = Self.stripCitations(answer)
        return ChatResponse(answer: cleaned, sources: Self.sources(for: cleaned, from: results))
    }

    // MARK: - 출처 필터링 / 인용 정리

    /// 검색 결과 중 "관련 있는" 출처만 남긴다. 최상위 점수 대비 상대 마진과 절대 하한을
    /// 함께 적용해, 무관한 결과가 무조건 노출되는 것을 막는다. (상수는 실사용 후 튜닝 가능)
    nonisolated private static let relevanceFloor: Float = 0.4
    nonisolated private static let relativeMargin: Float = 0.1

    nonisolated static func relevantSources(from results: [SearchResult]) -> [SearchResult] {
        guard let top = results.first?.score else { return [] }
        let cutoff = max(relevanceFloor, top - relativeMargin)
        return Array(results.filter { $0.score >= cutoff }.prefix(5))
    }

    /// 일반 지식 답변(규칙2)임을 알리는 마커. 답변 첫 줄에 위치한다.
    nonisolated static let noMemoryMarker = "💡 메모리에 관련 정보가 없어"

    /// LLM이 일반 지식으로 답한 경우(💡 마커) 출처를 표시하지 않는다.
    /// 임베딩이 느슨하게 매칭돼 하한을 넘었더라도, 실제 답변이 메모리를 쓰지 않았으면 출처를 비운다.
    nonisolated static func sources(for answer: String, from results: [SearchResult]) -> [SearchResult] {
        answer.hasPrefix(noMemoryMarker) ? [] : results
    }

    /// 답변 본문에 남을 수 있는 대괄호 번호 인용([1], [23] 등)을 제거한다.
    /// 마크다운 링크 `[텍스트](url)`는 숫자만 매칭하므로 영향받지 않는다.
    nonisolated static func stripCitations(_ text: String) -> String {
        let cleaned = text.replacingOccurrences(
            of: #"\s?\[\d+\]"#, with: "", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func suggestTitle(for query: String, answer: String) async -> String? {
        let messages: [[String: String]] = [
            ["role": "system", "content": """
                You generate a very short conversation title (2-4 words) summarizing the topic. \
                Respond with ONLY the title text. No quotes, no punctuation, no explanation. \
                Match the language of the user's question.
                """],
            ["role": "user", "content": "User question: \(query)\n\nWrite a 2-4 word title."],
        ]
        do {
            let raw = try await completeChat(messages: messages)
            var title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\"", with: "")
            if let firstLine = title.split(separator: "\n").first {
                title = String(firstLine)
            }
            title = String(title.prefix(40)).trimmingCharacters(in: .whitespacesAndNewlines)
            return title.isEmpty ? nil : title
        } catch {
            return nil
        }
    }

    func resetSession() {}

    // MARK: - Message assembly

    private func buildMessages(query: String, conversationId: String,
                               results: [SearchResult]) throws -> [[String: String]] {
        var messages: [[String: String]] = [["role": "system", "content": instructions]]

        let previous = try messageRepository.fetchLast(conversationId: conversationId, limit: historyLimit)
        for msg in previous {
            messages.append([
                "role": msg.role == .user ? "user" : "assistant",
                "content": msg.content,
            ])
        }

        let contextBlock = buildContext(from: results)
        let userContent: String
        if results.isEmpty {
            userContent = "Question: \(query)\n\nNo relevant memories found. Answer using your general knowledge."
        } else {
            userContent = """
                Question: \(query)

                Sources from user's memory:
                \(contextBlock)
                """
        }
        messages.append(["role": "user", "content": userContent])
        return messages
    }

    private func buildContext(from sources: [SearchResult]) -> String {
        var context = ""
        var remaining = maxContextChars
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        for (index, result) in sources.enumerated() {
            guard remaining > 0 else { break }
            let source = result.source
            var entry = "[\(index + 1)] "

            if let app = source.application {
                entry += "(\(app)"
                if let title = source.windowTitle { entry += " - \(title)" }
                entry += ") "
            }
            entry += dateFormatter.string(from: source.capturedAt) + "\n"

            if let summary = source.summary, !summary.isEmpty {
                entry += "Summary: \(summary)\n"
            }
            if let content = source.content, !content.isEmpty {
                entry += String(content.prefix(remaining))
            } else if let ocrText = source.ocrText, !ocrText.isEmpty {
                entry += String(ocrText.prefix(remaining))
            } else if let transcript = source.transcript, !transcript.isEmpty {
                entry += String(transcript.prefix(remaining))
            }
            if let note = source.userNote, !note.isEmpty {
                entry += "\n[User Note: \(note)]"
            }
            entry += "\n---\n"
            remaining -= entry.count
            context += entry
        }
        return context
    }

    // MARK: - Networking

    private func makeRequest(body: [String: Any]) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// 스트리밍 채팅 완성. delta를 onToken으로 흘려보내고 전체 텍스트를 반환한다.
    private func streamChat(messages: [[String: String]],
                            onToken: @Sendable @escaping (String) -> Void) async throws -> String {
        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "stream": true,
        ]
        let request = try makeRequest(body: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        try validateStatus(response)

        var full = ""
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let piece = delta["content"] as? String,
                  !piece.isEmpty else {
                continue
            }
            full += piece
            onToken(piece)
        }
        return full.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 비스트리밍 채팅 완성. 전체 응답 문자열을 반환한다.
    private func completeChat(messages: [[String: String]]) async throws -> String {
        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "stream": false,
        ]
        let request = try makeRequest(body: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: data)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LunaError.invalidResponse
        }
        return content
    }

    private func validateStatus(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            throw LunaError.httpStatus(http.statusCode, nil)
        }
    }

    private func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { ($0?["error"] as? [String: Any])?["message"] as? String }
            throw LunaError.httpStatus(http.statusCode, message)
        }
    }
}

nonisolated enum LunaError: LocalizedError {
    case invalidResponse
    case httpStatus(Int, String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "OpenAI 응답을 해석하지 못했습니다."
        case .httpStatus(let code, let message):
            if code == 401 {
                return "OpenAI API 키가 유효하지 않습니다. 설정에서 키를 확인해 주세요."
            }
            if code == 429 {
                return "OpenAI 사용량 한도에 도달했습니다. 잠시 후 다시 시도해 주세요."
            }
            return "OpenAI 오류(\(code))\(message.map { ": \($0)" } ?? "")"
        }
    }
}
