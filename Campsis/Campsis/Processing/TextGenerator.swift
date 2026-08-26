import Foundation

struct Analysis: Sendable {
    let summary: String
    let topics: [String]
}

enum TextGeneratorError: Error, Sendable {
    case guardrailRefusal
    case emptyInput
    case generationFailed(underlying: Error)
}

protocol TextGenerator: Sendable {
    func analyze(_ text: String) async throws -> Analysis
}
