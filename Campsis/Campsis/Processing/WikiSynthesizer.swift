import Foundation

/// 재합성에 넘길 새 메모(정리본) 입력.
nonisolated struct WikiNoteInput: Sendable {
    let title: String
    let summary: String?
    let body: String
    let capturedAt: Date
}

/// 위키 종합 결과: 재구성된 페이지 MD + 요약 + 관련 토픽(백링크 후보).
nonisolated struct SynthesizedWiki: Sendable {
    let markdown: String
    let summary: String?
    let relatedTopics: [String]
}

/// 위키 페이지를 종합/재작성한다. 백엔드 교체 가능하도록 프로토콜로 추상화(현재 Luna만).
protocol WikiSynthesizer: Sendable {
    /// 기존 페이지(있으면)에 새 메모들을 **통합**한 새 페이지를 만든다(증분, §6).
    func synthesize(title: String, currentMarkdown: String?,
                    newNotes: [WikiNoteInput]) async throws -> SynthesizedWiki
}

/// GPT-5.6 Luna로 위키를 증분 재합성한다. `[현재 페이지 + 새 메모]`만 전달해 비용 선형(§6).
actor LunaWikiSynthesizer: WikiSynthesizer {
    private let apiKey: String
    private let model: String
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let maxNoteChars = 2000
    private let maxTotalChars = 14000

    private let instructions = """
        You maintain a user's personal knowledge wiki page. You are given the CURRENT wiki page \
        (may be empty) and NEW notes to integrate. Respond with a SINGLE JSON object with exactly:
        {
          "markdown": string — the FULL rewritten wiki page in Markdown,
          "summary": string — 1-2 sentence overview of the whole page,
          "related_topics": string[] — 0-6 related topic names (other wikis this links to)
        }
        Rules:
        1. Output ONLY the JSON object. No prose or code fences.
        2. INTEGRATE, do not append. Synthesize and reorganize into a coherent page. Never just \
           concatenate the new notes at the bottom.
        3. Be faithful — do NOT invent facts. Preserve concrete details (names, numbers, URLs, code).
        4. Respect user-edited content; keep its meaning.
        5. If new info CONTRADICTS existing content, flag it inline (e.g. "⚠️ 상충: …").
        6. Match the language of the content (Korean notes → Korean page).
        7. Structure the markdown as:
           # {title}
           {2-4 sentence synthesis}

           ## 핵심 포인트
           - …

           ## 구성 메모
           - {note title} (YYYY-MM-DD)
           (Do NOT add a "관련 위키" section; related_topics is returned separately.)
        """

    init(apiKey: String, model: String = "gpt-5.6-luna") {
        self.apiKey = apiKey
        self.model = model
    }

    func synthesize(title: String, currentMarkdown: String?,
                    newNotes: [WikiNoteInput]) async throws -> SynthesizedWiki {
        let input = buildInput(title: title, currentMarkdown: currentMarkdown, newNotes: newNotes)
        guard !input.isEmpty else { throw MarkdownGeneratorError.emptyInput }

        let messages: [[String: Any]] = [
            ["role": "system", "content": instructions],
            ["role": "user", "content": input],
        ]
        let raw = try await completeChat(messages: messages)
        return Self.parse(raw, fallbackTitle: title)
    }

    private func buildInput(title: String, currentMarkdown: String?,
                            newNotes: [WikiNoteInput]) -> String {
        var parts: [String] = ["[위키 제목]\n\(title)"]

        if let md = currentMarkdown, !md.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("[기존 위키 페이지]\n\(md)")
        } else {
            parts.append("[기존 위키 페이지]\n(아직 없음 — 아래 메모들로 이 페이지를 처음 만듭니다)")
        }

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        var noteBlocks: [String] = []
        for note in newNotes {
            var block = "- \(note.title) (\(df.string(from: note.capturedAt)))"
            if let s = note.summary, !s.isEmpty { block += "\n  요약: \(s)" }
            let body = String(note.body.prefix(maxNoteChars))
            if !body.isEmpty { block += "\n  내용: \(body)" }
            noteBlocks.append(block)
        }
        parts.append("[새로 추가된 메모 \(newNotes.count)개]\n" + noteBlocks.joined(separator: "\n\n"))

        return String(parts.joined(separator: "\n\n").prefix(maxTotalChars))
    }

    private nonisolated static func parse(_ raw: String, fallbackTitle: String) -> SynthesizedWiki {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let markdown = (json["markdown"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let markdown, !markdown.isEmpty {
                let summary = (json["summary"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let related = (json["related_topics"] as? [String])?
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty } ?? []
                return SynthesizedWiki(markdown: markdown,
                                       summary: summary?.isEmpty == false ? summary : nil,
                                       relatedTopics: related)
            }
        }
        // 폴백: JSON 파싱 실패 시 응답 전체를 페이지 본문으로.
        return SynthesizedWiki(markdown: trimmed.isEmpty ? "# \(fallbackTitle)" : trimmed,
                               summary: nil, relatedTopics: [])
    }

    // MARK: - Networking (LunaMarkdownGenerator와 동일 패턴)

    private func completeChat(messages: [[String: Any]]) async throws -> String {
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
