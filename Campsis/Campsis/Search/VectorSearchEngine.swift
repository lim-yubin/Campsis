import Accelerate
import Foundation

nonisolated struct SearchResult: Sendable {
    let source: Source
    let score: Float
    let rank: Int
}

actor VectorSearchEngine {
    private let embeddingService: EmbeddingService
    private let embeddingRepository: EmbeddingRepository
    private let sourceRepository: SourceRepository

    init(embeddingService: EmbeddingService, embeddingRepository: EmbeddingRepository,
         sourceRepository: SourceRepository) {
        self.embeddingService = embeddingService
        self.embeddingRepository = embeddingRepository
        self.sourceRepository = sourceRepository
    }

    func search(query: String, topN: Int = 20, minScore: Float = 0.3) async throws -> [SearchResult] {
        try await embeddingService.loadIfNeeded()

        let queryVector = try await embeddingService.embed(query)
        let records = try embeddingRepository.fetchAll(
            model: EmbeddingService.modelName,
            version: EmbeddingService.embeddingVersion
        )

        guard !records.isEmpty else { return [] }

        var scored: [(sourceId: String, score: Float)] = []
        scored.reserveCapacity(records.count)

        for record in records {
            let docVector = record.vectorAsFloats()
            let similarity = cosineSimilarity(queryVector, docVector)
            if similarity >= minScore {
                scored.append((sourceId: record.sourceId, score: similarity))
            }
        }

        scored.sort { $0.score > $1.score }
        let topResults = scored.prefix(topN)

        var results: [SearchResult] = []
        for (rank, item) in topResults.enumerated() {
            if let source = try? sourceRepository.fetch(id: item.sourceId) {
                results.append(SearchResult(source: source, score: item.score, rank: rank + 1))
            }
        }

        return results
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        let n = vDSP_Length(a.count)

        var dot: Float = 0
        vDSP_dotpr(a, 1, b, 1, &dot, n)

        var normA: Float = 0
        var normB: Float = 0
        vDSP_svesq(a, 1, &normA, n)
        vDSP_svesq(b, 1, &normB, n)

        let denom = sqrt(normA) * sqrt(normB)
        guard denom > 1e-9 else { return 0 }

        return dot / denom
    }
}
