import Foundation
@preconcurrency import GRDB

nonisolated struct MessageRepository: Sendable {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    func save(_ message: inout Message) throws {
        try dbQueue.write { db in
            try message.save(db)
        }
    }

    func fetchAll(conversationId: String) throws -> [Message] {
        try dbQueue.read { db in
            try Message
                .filter(Column("conversation_id") == conversationId)
                .order(Column("created_at").asc)
                .fetchAll(db)
        }
    }

    func fetchLast(conversationId: String, limit: Int = 20) throws -> [Message] {
        try dbQueue.read { db in
            try Message
                .filter(Column("conversation_id") == conversationId)
                .order(Column("created_at").desc)
                .limit(limit)
                .fetchAll(db)
                .reversed()
        }
    }

    func count(conversationId: String) throws -> Int {
        try dbQueue.read { db in
            try Message
                .filter(Column("conversation_id") == conversationId)
                .fetchCount(db)
        }
    }

    func deleteAll(conversationId: String) throws {
        try dbQueue.write { db in
            _ = try Message
                .filter(Column("conversation_id") == conversationId)
                .deleteAll(db)
        }
    }
}
