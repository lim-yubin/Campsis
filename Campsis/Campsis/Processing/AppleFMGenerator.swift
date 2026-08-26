import Foundation
import FoundationModels

@available(macOS 26.0, *)
@Generable(description: "분석 결과: 요약과 주제 태그")
struct GeneratedAnalysis {
    @Guide(description: "원문의 핵심 내용을 1~2문장으로 요약")
    var summary: String

    @Guide(description: "주제 태그 목록, 1~5개")
    var topics: [String]
}

@available(macOS 26.0, *)
struct AppleFMGenerator: TextGenerator {
    private let instructions: String = """
        You are a personal memory assistant. Analyze the given text and produce:
        1. A concise summary (1-2 sentences) capturing the key information.
        2. Topic tags (1-5 tags) that categorize the content.

        Rules:
        - Write summary in the same language as the input text.
        - Tags should be short (1-3 words each).
        - Tags can be in Korean or English depending on the content.
        - Focus on factual content, not formatting or metadata.
        """

    func analyze(_ text: String) async throws -> Analysis {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TextGeneratorError.emptyInput
        }

        let model = SystemLanguageModel.default
        guard model.availability == .available else {
            throw TextGeneratorError.generationFailed(
                underlying: NSError(domain: "AppleFM", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "Apple Intelligence is not available"])
            )
        }

        let session = LanguageModelSession(model: model, instructions: instructions)

        let prompt = "Analyze this content:\n\n\(text.prefix(6000))"

        do {
            let response = try await session.respond(to: prompt, generating: GeneratedAnalysis.self)
            let result = response.content
            return Analysis(summary: result.summary, topics: result.topics)
        } catch let error as LanguageModelSession.GenerationError {
            if case .guardrailViolation = error {
                throw TextGeneratorError.guardrailRefusal
            }
            throw TextGeneratorError.generationFailed(underlying: error)
        } catch {
            throw TextGeneratorError.generationFailed(underlying: error)
        }
    }
}
