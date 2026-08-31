import Foundation

/// Luna 단일 이해 결과: 제목·요약·태그·본문(MD)을 한 번의 호출로 얻는다.
nonisolated struct GeneratedNote: Sendable {
    let title: String?
    let summary: String?
    let tags: [String]
    let markdown: String
}

/// 캡처한 소스를 "편집 가능한 마크다운 지식 노트(진실원)"로 변환한다 (D39).
///
/// 백엔드는 교체 가능하도록 프로토콜로 추상화한다. 현재는 GPT-5.6 Luna(클라우드)만 구현.
/// 로컬 전용 모드에서는 주입하지 않아(nil) MD 생성을 건너뛴다.
protocol MarkdownGenerator: Sendable {
    func generate(from source: Source) async throws -> GeneratedNote
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
        You convert a user's captured memory into a structured knowledge note. \
        Respond with a SINGLE JSON object with exactly these keys:
        {
          "title": string — a concise title capturing the essence,
          "summary": string — 1-2 sentence summary,
          "tags": string[] — 2-5 relevant keywords,
          "markdown": string — the full note in Markdown (H1 title, short summary, then headings/bullets/bold as helpful)
        }
        Rules:
        1. Output ONLY the JSON object. No prose or code fences around it.
        2. Inside "markdown", do NOT wrap the whole note in a code block.
        3. Be faithful to the source. Do NOT invent facts that are not present. \
           If the source is short, keep the note short.
        4. Preserve important details (names, numbers, URLs, code).
        5. Match the language of the source (Korean source → Korean note).
        6. If an image is attached, read ALL visible text in it and interpret its \
           meaningful content (UI, chart, document, photo) faithfully — this replaces separate OCR.
        """

    init(apiKey: String, model: String = "gpt-5.6-luna") {
        self.apiKey = apiKey
        self.model = model
    }

    func generate(from source: Source) async throws -> GeneratedNote {
        let input = Self.buildInput(from: source, limit: maxInputChars)
        let imageDataURL = Self.imageDataURL(for: source)
        guard !input.isEmpty || imageDataURL != nil else { throw MarkdownGeneratorError.emptyInput }

        // 이미지가 있으면 Luna 비전에 직접 입력한다 (7.9): 단일 호출로 OCR+이해+맥락+태깅.
        let userContent: Any
        if let imageDataURL {
            var parts: [[String: Any]] = []
            if !input.isEmpty {
                parts.append(["type": "text", "text": input])
            }
            parts.append(["type": "image_url", "image_url": ["url": imageDataURL]])
            userContent = parts
        } else {
            userContent = input
        }

        let messages: [[String: Any]] = [
            ["role": "system", "content": instructions],
            ["role": "user", "content": userContent],
        ]
        let raw = try await completeChat(messages: messages)
        return Self.parseNote(from: raw)
    }

    /// Luna의 JSON 응답을 GeneratedNote로 파싱한다. 파싱 실패 시 전체를 markdown으로 폴백.
    private nonisolated static func parseNote(from raw: String) -> GeneratedNote {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let markdown = (json["markdown"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let markdown, !markdown.isEmpty {
                let title = (json["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let summary = (json["summary"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let tags = (json["tags"] as? [String])?
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty } ?? []
                return GeneratedNote(
                    title: title?.isEmpty == false ? title : nil,
                    summary: summary?.isEmpty == false ? summary : nil,
                    tags: tags,
                    markdown: markdown
                )
            }
        }
        // 폴백: JSON이 아니거나 markdown 키가 없으면 전체 응답을 노트 본문으로 사용.
        return GeneratedNote(title: nil, summary: nil, tags: [], markdown: trimmed)
    }

    /// 소스에 이미지(스크린샷/이미지 파일)가 있으면 base64 data URL로 인코딩한다.
    private nonisolated static func imageDataURL(for source: Source) -> String? {
        let relativePath: String?
        switch source.type {
        case .screenshot: relativePath = source.screenshotPath
        case .file: relativePath = source.filePath
        default: relativePath = nil
        }
        guard let rel = relativePath else { return nil }

        let mime: String
        switch (rel as NSString).pathExtension.lowercased() {
        case "png": mime = "image/png"
        case "jpg", "jpeg": mime = "image/jpeg"
        case "gif": mime = "image/gif"
        case "webp": mime = "image/webp"
        default: return nil  // pdf/txt/md 등은 이미지가 아님
        }

        let url = AppPaths.absoluteURL(from: rel)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return "data:\(mime);base64,\(data.base64EncodedString())"
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

    private func completeChat(messages: [[String: Any]]) async throws -> String {
        // MD 구조화는 무거운 추론이 필요 없다. reasoning.effort를 낮춰 지연을 크게 줄인다.
        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "stream": false,
            "reasoning_effort": "low",
            "response_format": ["type": "json_object"],
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
