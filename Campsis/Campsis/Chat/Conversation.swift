import Foundation
@preconcurrency import GRDB

nonisolated struct Conversation: Codable, Sendable, Identifiable {
    var id: String
    var title: String
    var createdAt: Date
    var updatedAt: Date

    init(title: String = "새 채팅") {
        self.id = UUID().uuidString
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

nonisolated extension Conversation: FetchableRecord, PersistableRecord {
    static let databaseTableName = "conversation"

    enum CodingKeys: String, CodingKey {
        case id, title
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
