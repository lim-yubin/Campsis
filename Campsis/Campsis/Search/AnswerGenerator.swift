import Foundation
import FoundationModels

@available(macOS 26.0, *)
struct AnswerGenerator {
    private let maxContextChars = 5000

    private let instructions = """
        You are a personal memory assistant. The user saved text clips, screenshots, and notes. \
        They are now searching their saved memories.

        Your job: synthesize a helpful answer from the provided sources.

        Rules:
        1. Base your answer ONLY on the provided sources.
        2. If ANY source contains even partially relevant information, use it to form an answer. \
           Prefer giving a best-effort answer over saying you don't know.
        3. Match the language of the user's question (Korean question → Korean answer).
        4. Be concise. Cite source numbers like [1], [2].
        5. Only say "관련 정보를 찾지 못했습니다." if NONE of the sources are even tangentially related.
        """

    func generate(query: String, sources: [SearchResult]) async throws -> String {
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            return "Apple Intelligence를 사용할 수 없습니다. 시스템 설정에서 활성화해 주세요."
        }

        let contextBlock = buildContext(from: sources)
        let prompt = """
            Question: \(query)

            Sources:
            \(contextBlock)
            """

        let session = LanguageModelSession(model: model, instructions: instructions)

        do {
            let response = try await session.respond(to: prompt)
            return response.content
        } catch let error as LanguageModelSession.GenerationError {
            if case .guardrailViolation = error {
                return "이 질문에 대해 답변을 생성할 수 없습니다."
            }
            throw error
        }
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
