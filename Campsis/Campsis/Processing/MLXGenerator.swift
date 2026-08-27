import Foundation
import MLXLLM
import MLXLMCommon
@preconcurrency import HuggingFace
@preconcurrency import Tokenizers

private enum HuggingFaceDownloaderError: Error {
    case invalidRepositoryID(String)
}

private struct CampsisDownloader: MLXLMCommon.Downloader {
    private let client = HubClient()

    func download(
        id: String,
        revision: String?,
        matching patterns: [String],
        useLatest: Bool,
        progressHandler: @Sendable @escaping (Progress) -> Void
    ) async throws -> URL {
        guard let repoID = HuggingFace.Repo.ID(rawValue: id) else {
            throw HuggingFaceDownloaderError.invalidRepositoryID(id)
        }
        let rev = revision ?? "main"
        return try await client.downloadSnapshot(
            of: repoID,
            revision: rev,
            matching: patterns,
            progressHandler: { @MainActor progress in
                progressHandler(progress)
            }
        )
    }
}

private struct CampsisTokenizerLoader: MLXLMCommon.TokenizerLoader {
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        let upstream = try await Tokenizers.AutoTokenizer.from(modelFolder: directory)
        return TokenizerBridge(upstream)
    }
}

private struct TokenizerBridge: @unchecked Sendable, MLXLMCommon.Tokenizer {
    private let upstream: any Tokenizers.Tokenizer

    init(_ upstream: any Tokenizers.Tokenizer) {
        self.upstream = upstream
    }

    func encode(text: String, addSpecialTokens: Bool) -> [Int] {
        upstream.encode(text: text, addSpecialTokens: addSpecialTokens)
    }

    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String {
        upstream.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens)
    }

    func convertTokenToId(_ token: String) -> Int? {
        upstream.convertTokenToId(token)
    }

    func convertIdToToken(_ id: Int) -> String? {
        upstream.convertIdToToken(id)
    }

    var bosToken: String? { upstream.bosToken }
    var eosToken: String? { upstream.eosToken }
    var unknownToken: String? { upstream.unknownToken }

    func applyChatTemplate(
        messages: [[String: any Sendable]],
        tools: [[String: any Sendable]]?,
        additionalContext: [String: any Sendable]?
    ) throws -> [Int] {
        let bridgedMessages = messages.map { $0 as [String: Any] }
        let bridgedTools = tools?.map { $0 as [String: Any] }
        let bridgedContext = additionalContext.map { $0 as [String: Any] }
        do {
            return try upstream.applyChatTemplate(
                messages: bridgedMessages,
                tools: bridgedTools,
                additionalContext: bridgedContext
            )
        } catch Tokenizers.TokenizerError.missingChatTemplate {
            throw MLXLMCommon.TokenizerError.missingChatTemplate
        }
    }
}

actor MLXGenerator: TextGenerator {
    var modelContainer: ModelContainer?
    private let modelId = "mlx-community/Qwen3-4B-4bit"

    func preload() async throws {
        _ = try await getModel()
        NSLog("[MLXGenerator] Model preloaded: \(modelId)")
    }

    func getLoadedContainer() -> ModelContainer? {
        modelContainer
    }

    func analyze(_ text: String) async throws -> Analysis {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TextGeneratorError.emptyInput
        }

        let container = try await getModel()
        let session = ChatSession(container, instructions: """
            You are a text analysis assistant. When given content, respond ONLY with a JSON object.
            No markdown fences, no explanation, just pure JSON.
            """)

        let prompt = """
        Analyze this content and respond with JSON: {"summary": "1-2 sentence summary in same language as input", "topics": ["tag1", "tag2"]}
        Tags: 1-5 short tags (1-3 words). Focus on factual content.

        Content:
        \(String(text.prefix(6000)))
        """

        do {
            let response = try await session.respond(to: prompt)
            return parseAnalysis(from: response)
        } catch {
            throw TextGeneratorError.generationFailed(underlying: error)
        }
    }

    private func getModel() async throws -> ModelContainer {
        if let m = modelContainer { return m }
        NSLog("[MLXGenerator] Loading model: \(modelId)...")
        let m = try await loadModelContainer(
            from: CampsisDownloader(),
            using: CampsisTokenizerLoader(),
            id: modelId
        )
        modelContainer = m
        NSLog("[MLXGenerator] Model loaded successfully")
        return m
    }

    private func parseAnalysis(from text: String) -> Analysis {
        var cleaned = text
        if let thinkEnd = cleaned.range(of: "</think>") {
            cleaned = String(cleaned[thinkEnd.upperBound...])
        }
        cleaned = cleaned
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return Analysis(summary: String(text.prefix(200)), topics: [])
        }

        let summary = json["summary"] as? String ?? String(text.prefix(200))
        let topics = json["topics"] as? [String] ?? []
        return Analysis(summary: summary, topics: topics)
    }
}
