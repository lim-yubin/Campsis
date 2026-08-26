import Foundation
import MLXLMCommon

struct ChatResponse: Sendable {
    let answer: String
    let sources: [SearchResult]
}

protocol ChatEngineProtocol: Sendable {
    func send(query: String, conversationId: String) async throws -> ChatResponse
    func resetSession() async
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
        You are a personal memory assistant. The user saved text clips, screenshots, notes, and files. \
        They are now chatting with you to recall their saved memories.

        IMPORTANT - Output format:
        - You MUST answer in natural language prose with markdown formatting (headings, bullets, bold).
        - DO NOT output JSON objects or arrays.
        - DO NOT wrap your entire answer in code blocks.
        - Only use code blocks when the user explicitly asks for code snippets or data formats.

        Rules:
        1. Base your answer ONLY on the provided sources (context).
        2. If ANY source contains even partially relevant information, use it to form an answer. \
           Prefer giving a best-effort answer over saying you don't know.
        3. Match the language of the user's question (Korean question → Korean answer).
        4. Be concise but helpful. Cite source numbers like [1], [2] when referencing specific memories.
        5. Only say "관련 정보를 찾지 못했습니다." if NONE of the sources are even tangentially related.
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
            prompt = "Question: \(query)\n\n(No relevant sources found in memory.)" + formatReminder
        } else {
            prompt = """
                Question: \(query)

                Sources:
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
