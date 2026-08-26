import Foundation
@preconcurrency import GRDB

nonisolated struct EmbeddingRepository {
    let dbQueue: DatabaseQueue

    func save(_ record: inout EmbeddingRecord) throws {
        try dbQueue.write { db in
            try record.save(db)
        }
    }

    func fetchAll(model: String, version: String) throws -> [EmbeddingRecord] {
        try dbQueue.read { db in
            try EmbeddingRecord
                .filter(EmbeddingRecord.CodingKeys.embeddingModel == model)
                .filter(EmbeddingRecord.CodingKeys.embeddingVersion == version)
                .fetchAll(db)
        }
    }

    func fetch(forSourceId sourceId: String) throws -> EmbeddingRecord? {
        try dbQueue.read { db in
            try EmbeddingRecord
                .filter(EmbeddingRecord.CodingKeys.sourceId == sourceId)
                .fetchOne(db)
        }
    }

    func delete(forSourceId sourceId: String) throws {
        try dbQueue.write { db in
            _ = try EmbeddingRecord
                .filter(EmbeddingRecord.CodingKeys.sourceId == sourceId)
                .deleteAll(db)
        }
    }

    func sourcesWithoutEmbedding(model: String, version: String, limit: Int = 50) throws -> [Source] {
        try dbQueue.read { db in
            let sql = """
                SELECT s.* FROM source s
                LEFT JOIN embedding e ON e.source_id = s.id
                    AND e.embedding_model = ? AND e.embedding_version = ?
                WHERE e.id IS NULL AND s.processing_status = 'completed'
                LIMIT ?
                """
            return try Source.fetchAll(db, sql: sql, arguments: [model, version, limit])
        }
    }
}
