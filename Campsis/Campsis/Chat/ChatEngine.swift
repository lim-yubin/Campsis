import Foundation
import MLXLMCommon

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

nonisolated private struct SendableChatSession: @unchecked Sendable {
    let session: ChatSession
}

actor MLXChatEngine: ChatEngineProtocol {
    private let searchEngine: VectorSearchEngine
    private let conversationRepository: ConversationRepository
    private let messageRepository: MessageRepository
    private let sourceRepository: SourceRepository
    private let maxContextChars = 8000
    private let modelContainer: ModelContainer

    private var chatSession: SendableChatSession?
    private var currentConversationId: String?

    private let instructions = """
        You are a personal AI assistant with access to the user's saved memories \
        (text clips, screenshots, notes, files). You also have general knowledge.

        IMPORTANT - Output format:
        - You MUST answer in natural language prose with markdown formatting (headings, bullets, bold).
        - DO NOT output JSON objects or arrays.
        - DO NOT wrap your entire answer in code blocks.
        - Only use code blocks when the user explicitly asks for code snippets or data formats.

        Rules:
        1. If relevant sources (memories) are provided, base your answer primarily on them. \
           Cite source numbers like [1], [2] when referencing specific memories.
        2. If no relevant sources are found, answer using your general knowledge. \
           In this case, start your answer with "💡 메모리에 관련 정보가 없어 일반 지식으로 답변합니다." on its own line.
        3. If sources are partially relevant, combine memory-based info with general knowledge. \
           Clearly distinguish which parts come from memories vs general knowledge.
        4. Match the language of the user's question (Korean question → Korean answer).
        5. Be concise but helpful.
        6. You can engage in follow-up conversation. If the user asks a clarifying question about a \
           previous answer, use the conversation context plus any new sources.
        """

    init(searchEngine: VectorSearchEngine,
         conversationRepository: ConversationRepository,
         messageRepository: MessageRepository,
         sourceRepository: SourceRepository,
         modelContainer: ModelContainer) {
        self.searchEngine = searchEngine
        self.conversationRepository = conversationRepository
        self.messageRepository = messageRepository
        self.sourceRepository = sourceRepository
        self.modelContainer = modelContainer
    }

    func send(query: String, conversationId: String) async throws -> ChatResponse {
        if currentConversationId != conversationId {
            chatSession = nil
            currentConversationId = conversationId
        }

        let results = try await searchEngine.search(query: query, topN: 5)

        let contextBlock = buildContext(from: results)
        let formatReminder = "\n\nRemember: Answer in natural language with markdown. Do NOT output JSON."
        let prompt: String
        if results.isEmpty {
            prompt = "Question: \(query)\n\nNo relevant memories found. Answer using your general knowledge." + formatReminder
        } else {
            prompt = """
                Question: \(query)

                Sources from user's memory:
                \(contextBlock)
                """ + formatReminder
        }

        if chatSession == nil {
            let previousMessages = try messageRepository.fetchLast(
                conversationId: conversationId, limit: 6)

            var history: [Chat.Message] = []
            for msg in previousMessages {
                let role: Chat.Message.Role = msg.role == .user ? .user : .assistant
                history.append(.init(role: role, content: msg.content))
            }

            chatSession = SendableChatSession(session: ChatSession(
                modelContainer,
                instructions: instructions,
                history: history
            ))
        }

        guard let wrapper = chatSession else {
            return ChatResponse(answer: "세션 초기화 실패", sources: results)
        }

        do {
            let response = try await wrapper.session.respond(to: prompt)
            return ChatResponse(answer: stripThinking(response), sources: results)
        } catch {
            let desc = error.localizedDescription
            if desc.contains("context") || desc.contains("memory") {
                let newWrapper = SendableChatSession(session: ChatSession(modelContainer, instructions: instructions))
                chatSession = newWrapper
                let retryResponse = try await newWrapper.session.respond(to: prompt)
                return ChatResponse(answer: stripThinking(retryResponse), sources: results)
            }
            throw error
        }
    }

    func sendStream(query: String, conversationId: String,
                    onToken: @Sendable @escaping (String) -> Void) async throws -> ChatResponse {
        if currentConversationId != conversationId {
            chatSession = nil
            currentConversationId = conversationId
        }

        let results = try await searchEngine.search(query: query, topN: 5)

        let contextBlock = buildContext(from: results)
        let formatReminder = "\n\nRemember: Answer in natural language with markdown. Do NOT output JSON."
        let prompt: String
        if results.isEmpty {
            prompt = "Question: \(query)\n\nNo relevant memories found. Answer using your general knowledge." + formatReminder
        } else {
            prompt = """
                Question: \(query)

                Sources from user's memory:
                \(contextBlock)
                """ + formatReminder
        }

        if chatSession == nil {
            let previousMessages = try messageRepository.fetchLast(
                conversationId: conversationId, limit: 6)

            var history: [Chat.Message] = []
            for msg in previousMessages {
                let role: Chat.Message.Role = msg.role == .user ? .user : .assistant
                history.append(.init(role: role, content: msg.content))
            }

            chatSession = SendableChatSession(session: ChatSession(
                modelContainer,
                instructions: instructions,
                history: history
            ))
        }

        guard let wrapper = chatSession else {
            return ChatResponse(answer: "세션 초기화 실패", sources: results)
        }

        do {
            let answer = try await streamAndCollect(session: wrapper.session, prompt: prompt, onToken: onToken)
            return ChatResponse(answer: answer, sources: results)
        } catch let error where !(error is CancellationError) {
            let desc = error.localizedDescription
            if desc.contains("context") || desc.contains("memory") {
                let newWrapper = SendableChatSession(session: ChatSession(modelContainer, instructions: instructions))
                chatSession = newWrapper
                let answer = try await streamAndCollect(session: newWrapper.session, prompt: prompt, onToken: onToken)
                return ChatResponse(answer: answer, sources: results)
            }
            throw error
        }
    }

    private func streamAndCollect(session: ChatSession, prompt: String,
                                  onToken: @Sendable @escaping (String) -> Void) async throws -> String {
        var raw = ""
        var emitted = 0
        for try await chunk in session.streamResponse(to: prompt) {
            try Task.checkCancellation()
            raw += chunk
            let visible = visiblePortion(raw)
            if visible.count > emitted {
                let delta = String(visible.dropFirst(emitted))
                emitted = visible.count
                onToken(delta)
            }
        }
        return stripThinking(raw)
    }

    private func visiblePortion(_ raw: String) -> String {
        if let r = raw.range(of: "</think>") {
            let after = raw[r.upperBound...]
            return String(after.drop(while: { $0 == "\n" || $0 == " " }))
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("<think") { return "" }
        return trimmed.isEmpty ? "" : raw
    }

    func suggestTitle(for query: String, answer: String) async -> String? {
        let session = ChatSession(modelContainer, instructions: """
            You generate a very short conversation title (2-4 words) summarizing the topic.
            Respond with ONLY the title text. No quotes, no surrounding punctuation, no explanation.
            Match the language of the user's question.
            """)
        let prompt = "User question: \(query)\n\nWrite a 2-4 word title."
        do {
            let raw = try await session.respond(to: prompt)
            var title = stripThinking(raw).trimmingCharacters(in: .whitespacesAndNewlines)
            title = title.replacingOccurrences(of: "\"", with: "")
            if let firstLine = title.split(separator: "\n").first {
                title = String(firstLine)
            }
            title = String(title.prefix(40)).trimmingCharacters(in: .whitespacesAndNewlines)
            return title.isEmpty ? nil : title
        } catch {
            return nil
        }
    }

    func resetSession() {
        chatSession = nil
        currentConversationId = nil
    }

    private func stripThinking(_ text: String) -> String {
        var cleaned = text
        if let thinkEnd = cleaned.range(of: "</think>") {
            cleaned = String(cleaned[thinkEnd.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return cleaned
    }

    private func buildContext(from sources: [SearchResult]) -> String {
        var context = ""
        var remaining = maxContextChars

        for (index, result) in sources.enumerated() {
            guard remaining > 0 else { break }

            let source = result.source
            var entry = "[\(index + 1)] "

            if let app = source.application {
                entry += "(\(app)"
                if let title = source.windowTitle {
                    entry += " - \(title)"
                }
                entry += ") "
            }

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
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
}
