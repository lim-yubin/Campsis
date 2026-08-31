import Foundation

/// 캡처한 소스를 "편집 가능한 마크다운 지식 노트(진실원)"로 변환한다 (D39).
///
/// 백엔드는 교체 가능하도록 프로토콜로 추상화한다. 현재는 GPT-5.6 Luna(클라우드)만 구현.
/// 로컬 전용 모드에서는 주입하지 않아(nil) MD 생성을 건너뛴다.
protocol MarkdownGenerator: Sendable {
    func generate(from source: Source) async throws -> String
}

nonisolated enum MarkdownGeneratorError: LocalizedError {
    case emptyInput
    case invalidResponse
    case httpStatus(Int, String?)

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "정리할 내용이 없습니다."
        case .invalidResponse:
            return "OpenAI 응답을 해석하지 못했습니다."
        case .httpStatus(let code, let message):
            if code == 401 { return "OpenAI API 키가 유효하지 않습니다." }
            if code == 429 { return "OpenAI 사용량 한도에 도달했습니다." }
            return "OpenAI 오류(\(code))\(message.map { ": \($0)" } ?? "")"
        }
    }
}

/// GPT-5.6 Luna로 MD를 생성한다. 소스의 원문/OCR/메모/메타데이터를 바탕으로
/// 충실하게(환각 없이) 구조화된 마크다운을 만든다.
actor LunaMarkdownGenerator: MarkdownGenerator {
    private let apiKey: String
    private let model: String
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let maxInputChars = 12000

    private let instructions = """
        You convert a user's captured memory into a clean, editable Markdown knowledge note. \
        Rules:
        1. Output ONLY Markdown. Do NOT wrap the whole note in a code block.
        2. Start with a concise H1 title (#) that captures the essence.
        3. Add a short 1-2 sentence summary, then organize the content with headings, \
           bullet points, and bold where helpful.
        4. Be faithful to the source. Do NOT invent facts that are not present. \
           If the source is short, keep the note short.
        5. Preserve important details (names, numbers, URLs, code).
        6. Match the language of the source (Korean source → Korean note).
        7. End with a short "태그:" line listing 2-5 relevant keywords.
        """

    init(apiKey: String, model: String = "gpt-5.6-luna") {
        self.apiKey = apiKey
        self.model = model
    }

    func generate(from source: Source) async throws -> String {
        let input = Self.buildInput(from: source, limit: maxInputChars)
        guard !input.isEmpty else { throw MarkdownGeneratorError.emptyInput }

        let messages: [[String: String]] = [
            ["role": "system", "content": instructions],
            ["role": "user", "content": input],
        ]
        let raw = try await completeChat(messages: messages)
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 소스의 텍스트 재료 + 메타데이터를 하나의 입력으로 조립한다.
    private nonisolated static func buildInput(from source: Source, limit: Int) -> String {
        var parts: [String] = []

        var meta: [String] = []
        if let app = source.application { meta.append("App: \(app)") }
        if let title = source.windowTitle { meta.append("Window: \(title)") }
        if let url = source.url { meta.append("URL: \(url)") }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        meta.append("Captured: \(formatter.string(from: source.capturedAt))")
        if !meta.isEmpty {
            parts.append("[Context]\n" + meta.joined(separator: "\n"))
        }

        if let note = source.userNote, !note.isEmpty {
            parts.append("[User Note]\n\(note)")
        }
        if let content = source.content, !content.isEmpty {
            parts.append("[Content]\n\(content)")
        }
        if let ocr = source.ocrText, !ocr.isEmpty {
            parts.append("[OCR]\n\(ocr)")
        }
        if let transcript = source.transcript, !transcript.isEmpty {
            parts.append("[Transcript]\n\(transcript)")
        }

        let joined = parts.joined(separator: "\n\n")
        return String(joined.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Networking (LunaChatEngine과 동일 패턴)

    private func completeChat(messages: [[String: String]]) async throws -> String {
        // MD 구조화는 무거운 추론이 필요 없다. reasoning.effort를 낮춰 지연을 크게 줄인다.
        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "stream": false,
            "reasoning_effort": "low",
        ]
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { ($0?["error"] as? [String: Any])?["message"] as? String }
            throw MarkdownGeneratorError.httpStatus(http.statusCode, message)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstMessage = choices.first?["message"] as? [String: Any],
              let content = firstMessage["content"] as? String else {
            throw MarkdownGeneratorError.invalidResponse
        }
        return content
    }
}
