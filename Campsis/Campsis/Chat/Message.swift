import Foundation
@preconcurrency import GRDB

nonisolated enum MessageRole: String, Codable, DatabaseValueConvertible, Sendable {
    case user
    case assistant
}

nonisolated struct Message: Codable, Sendable, Identifiable {
    var id: String
    var conversationId: String
    var role: MessageRole
    var content: String
    var sourceIds: String?
    var createdAt: Date

    init(conversationId: String, role: MessageRole, content: String, sourceIds: [String]? = nil) {
        self.id = UUID().uuidString
        self.conversationId = conversationId
        self.role = role
        self.content = content
        if let ids = sourceIds, !ids.isEmpty {
            self.sourceIds = ids.joined(separator: ",")
        } else {
            self.sourceIds = nil
        }
        self.createdAt = Date()
    }

    func referencedSourceIds() -> [String] {
        guard let ids = sourceIds, !ids.isEmpty else { return [] }
        return ids.components(separatedBy: ",")
    }
}

nonisolated extension Message: FetchableRecord, PersistableRecord {
    static let databaseTableName = "message"

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case role, content
        case sourceIds = "source_ids"
        case createdAt = "created_at"
    }
}
