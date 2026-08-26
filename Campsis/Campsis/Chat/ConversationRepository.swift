import Foundation
@preconcurrency import GRDB

nonisolated struct ConversationRepository: Sendable {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    func save(_ conversation: inout Conversation) throws {
        try dbQueue.write { db in
            try conversation.save(db)
        }
    }

    func update(_ conversation: inout Conversation) throws {
        conversation.updatedAt = Date()
        try dbQueue.write { db in
            try conversation.update(db)
        }
    }

    func delete(_ conversation: Conversation) throws {
        _ = try dbQueue.write { db in
            try conversation.delete(db)
        }
    }

    func fetch(id: String) throws -> Conversation? {
        try dbQueue.read { db in
            try Conversation.fetchOne(db, key: id)
        }
    }

    func fetchAll() throws -> [Conversation] {
        try dbQueue.read { db in
            try Conversation
                .order(Column("updated_at").desc)
                .fetchAll(db)
        }
    }

    func fetchRecent(limit: Int = 30) throws -> [Conversation] {
        try dbQueue.read { db in
            try Conversation
                .order(Column("updated_at").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }
}
