import Foundation
import FoundationModels

@available(macOS 26.0, *)
actor ChatEngine {
    private let searchEngine: VectorSearchEngine
    private let conversationRepository: ConversationRepository
    private let messageRepository: MessageRepository
    private let sourceRepository: SourceRepository
    private let maxContextChars = 5000

    private var session: LanguageModelSession?
    private var currentConversationId: String?

    private let instructions = """
        You are a personal memory assistant. The user saved text clips, screenshots, notes, and files. \
        They are now chatting with you to recall their saved memories.

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
         sourceRepository: SourceRepository) {
        self.searchEngine = searchEngine
        self.conversationRepository = conversationRepository
        self.messageRepository = messageRepository
        self.sourceRepository = sourceRepository
    }

    struct ChatResponse: Sendable {
        let answer: String
        let sources: [SearchResult]
    }

    func send(query: String, conversationId: String) async throws -> ChatResponse {
        if currentConversationId != conversationId {
            session = nil
            currentConversationId = conversationId
        }

        let results = try await searchEngine.search(query: query, topN: 5)

        let contextBlock = buildContext(from: results)
        let prompt: String
        if results.isEmpty {
            prompt = "Question: \(query)\n\n(No relevant sources found in memory.)"
        } else {
            prompt = """
                Question: \(query)

                Sources:
                \(contextBlock)
                """
        }

        if session == nil {
            let model = SystemLanguageModel.default
            guard model.isAvailable else {
                return ChatResponse(
                    answer: "Apple Intelligence를 사용할 수 없습니다. 시스템 설정에서 활성화해 주세요.",
                    sources: results
                )
            }

            let previousMessages = try messageRepository.fetchLast(conversationId: conversationId, limit: 4)
            session = LanguageModelSession(model: model, instructions: instructions)

            for msg in previousMessages {
                let _ = try? await session?.respond(to: msg.role == .user ? msg.content : "")
            }
        }

        do {
            let response = try await session!.respond(to: prompt)
            let sourceIds = results.map { $0.source.id }
            return ChatResponse(answer: response.content, sources: results)
        } catch let error as LanguageModelSession.GenerationError {
            if case .guardrailViolation = error {
                return ChatResponse(
                    answer: "이 질문에 대해 답변을 생성할 수 없습니다.",
                    sources: results
                )
            }
            throw error
        } catch {
            let desc = error.localizedDescription
            if desc.contains("context window") || desc.contains("Context") {
                session = nil
                let model = SystemLanguageModel.default
                session = LanguageModelSession(model: model, instructions: instructions)
                let retryResponse = try await session!.respond(to: prompt)
                let sourceIds = results.map { $0.source.id }
                return ChatResponse(answer: retryResponse.content, sources: results)
            }
            throw error
        }
    }

    func resetSession() {
        session = nil
        currentConversationId = nil
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
