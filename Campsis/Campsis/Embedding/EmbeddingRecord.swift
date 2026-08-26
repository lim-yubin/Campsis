import Foundation
@preconcurrency import GRDB

nonisolated struct EmbeddingRecord: Codable, Sendable, Identifiable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "embedding"

    var id: String
    var sourceId: String
    var vector: Data
    var embeddingModel: String
    var embeddingVersion: String
    var dimensions: Int
    var createdAt: Date

    enum CodingKeys: String, CodingKey, ColumnExpression {
        case id
        case sourceId = "source_id"
        case vector
        case embeddingModel = "embedding_model"
        case embeddingVersion = "embedding_version"
        case dimensions
        case createdAt = "created_at"
    }

    init(sourceId: String, vector: [Float], model: String, version: String) {
        self.id = UUID().uuidString
        self.sourceId = sourceId
        self.vector = vector.withUnsafeBufferPointer { Data(buffer: $0) }
        self.embeddingModel = model
        self.embeddingVersion = version
        self.dimensions = vector.count
        self.createdAt = Date()
    }

    func vectorAsFloats() -> [Float] {
        vector.withUnsafeBytes { raw in
            let buffer = raw.bindMemory(to: Float.self)
            return Array(buffer)
        }
    }
}
