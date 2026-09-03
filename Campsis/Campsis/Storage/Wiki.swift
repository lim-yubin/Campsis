import Foundation
@preconcurrency import GRDB

/// 위키 재합성/승격 되돌리기 스냅샷의 발생 사유 (OW4).
nonisolated enum WikiRevisionReason: String, Codable, DatabaseValueConvertible, Sendable {
    case resynthesis   // 증분 재합성 직전
    case edit          // 사용자 직접 편집 직전
    case promotion     // 승격(구성원 추가) 배치 직전
}

/// 토픽 허브 = 소속 메모(정리본)들을 종합한 문서 (Phase 8).
/// MD 본문은 파일 진실원(D39), 여기에는 메타데이터만 둔다.
nonisolated struct Wiki: Codable, Sendable, Identifiable, Hashable {
    var id: String
    var title: String
    /// 정규화 키(중복 매칭·병합용, OW3 T_merge).
    var topicSlug: String
    var summary: String?
    var markdownPath: String?
    var markdownStatus: MarkdownStatus
    var markdownUpdatedAt: Date?
    /// 사람이 직접 편집했는지. 자동 재합성 덮어쓰기 보호(§10).
    var markdownEdited: Bool
    /// 구성 메모 수(고아/빈약 판정, Lint).
    var memberCount: Int
    var createdAt: Date
    var updatedAt: Date

    init(title: String, topicSlug: String, summary: String? = nil) {
        self.id = UUID().uuidString
        self.title = title
        self.topicSlug = topicSlug
        self.summary = summary
        self.markdownPath = nil
        self.markdownStatus = .pending
        self.markdownUpdatedAt = nil
        self.markdownEdited = false
        self.memberCount = 0
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

nonisolated extension Wiki: FetchableRecord, PersistableRecord {
    static let databaseTableName = "wiki"

    enum Columns: String, ColumnExpression {
        case id, title, summary
        case topicSlug = "topic_slug"
        case markdownPath = "markdown_path"
        case markdownStatus = "markdown_status"
        case markdownUpdatedAt = "markdown_updated_at"
        case markdownEdited = "markdown_edited"
        case memberCount = "member_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    enum CodingKeys: String, CodingKey {
        case id, title, summary
        case topicSlug = "topic_slug"
        case markdownPath = "markdown_path"
        case markdownStatus = "markdown_status"
        case markdownUpdatedAt = "markdown_updated_at"
        case markdownEdited = "markdown_edited"
        case memberCount = "member_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// 메모(정리본) ↔ 위키 다대다 링크.
nonisolated struct NoteWikiLink: Codable, Sendable, Hashable {
    var sourceId: String
    var wikiId: String
    var addedAt: Date
    /// 승격 시 매칭 유사도(감사·정렬·임계값 튜닝용, OW3).
    var matchScore: Double?

    init(sourceId: String, wikiId: String, matchScore: Double? = nil) {
        self.sourceId = sourceId
        self.wikiId = wikiId
        self.addedAt = Date()
        self.matchScore = matchScore
    }
}

nonisolated extension NoteWikiLink: FetchableRecord, PersistableRecord {
    static let databaseTableName = "note_wiki_link"

    enum Columns: String, ColumnExpression {
        case sourceId = "source_id"
        case wikiId = "wiki_id"
        case addedAt = "added_at"
        case matchScore = "match_score"
    }

    enum CodingKeys: String, CodingKey {
        case sourceId = "source_id"
        case wikiId = "wiki_id"
        case addedAt = "added_at"
        case matchScore = "match_score"
    }
}

/// 위키↔위키 링크의 출처(provenance). 자동 유사도 링크만 안전히 재계산/정리하기 위함.
nonisolated enum WikiLinkKind: String, Codable, DatabaseValueConvertible, Sendable {
    case explicit      // 사용자/수동 또는 v9 이전 기존 링크(기본값)
    case comembership  // 승격 시 공동 소속(같은 메모가 여러 위키로) — weight 1.0
    case relatedTopic  // 재합성 LLM related_topics가 기존 slug와 일치 — weight 0.8
    case similarity    // 위키 임베딩 유사도 자동 백링크(재계산 대상)
}

/// 위키 ↔ 위키 관련 토픽 백링크.
nonisolated struct WikiWikiLink: Codable, Sendable, Hashable {
    var fromWikiId: String
    var toWikiId: String
    var weight: Double?
    /// 링크 출처. 재계산 시 `similarity`만 교체하고 나머지는 보존한다.
    var kind: WikiLinkKind

    init(fromWikiId: String, toWikiId: String, weight: Double? = nil,
         kind: WikiLinkKind = .explicit) {
        self.fromWikiId = fromWikiId
        self.toWikiId = toWikiId
        self.weight = weight
        self.kind = kind
    }
}

nonisolated extension WikiWikiLink: FetchableRecord, PersistableRecord {
    static let databaseTableName = "wiki_wiki_link"

    enum Columns: String, ColumnExpression {
        case fromWikiId = "from_wiki_id"
        case toWikiId = "to_wiki_id"
        case weight
        case kind
    }

    enum CodingKeys: String, CodingKey {
        case fromWikiId = "from_wiki_id"
        case toWikiId = "to_wiki_id"
        case weight
        case kind
    }
}

/// 위키 MD 되돌리기 스냅샷 (OW4). 쓰기 직전 이전 버전을 파일+이 레코드로 보관.
nonisolated struct WikiRevision: Codable, Sendable, Identifiable, Hashable {
    var id: String
    var wikiId: String
    var snapshotPath: String
    var summary: String?
    var reason: WikiRevisionReason
    /// 승격 배치서 그때 추가된 메모 id들(JSON). 되돌리기 시 해당 링크만 제거.
    var addedSourceIds: String?
    var createdAt: Date

    init(wikiId: String, snapshotPath: String, reason: WikiRevisionReason,
         summary: String? = nil, addedSourceIds: [String]? = nil) {
        self.id = UUID().uuidString
        self.wikiId = wikiId
        self.snapshotPath = snapshotPath
        self.reason = reason
        self.summary = summary
        self.addedSourceIds = addedSourceIds.flatMap { ids in
            (try? JSONEncoder().encode(ids)).flatMap { String(data: $0, encoding: .utf8) }
        }
        self.createdAt = Date()
    }

    /// 저장된 JSON을 다시 배열로.
    var addedSourceIdList: [String] {
        guard let addedSourceIds, let data = addedSourceIds.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}

nonisolated extension WikiRevision: FetchableRecord, PersistableRecord {
    static let databaseTableName = "wiki_revision"

    enum Columns: String, ColumnExpression {
        case id, summary, reason
        case wikiId = "wiki_id"
        case snapshotPath = "snapshot_path"
        case addedSourceIds = "added_source_ids"
        case createdAt = "created_at"
    }

    enum CodingKeys: String, CodingKey {
        case id, summary, reason
        case wikiId = "wiki_id"
        case snapshotPath = "snapshot_path"
        case addedSourceIds = "added_source_ids"
        case createdAt = "created_at"
    }
}

/// 위키 페이지 임베딩 (OW2). 기존 `EmbeddingRecord`(source FK)와 동형이나 위키를 참조하는 별도 테이블.
nonisolated struct WikiEmbeddingRecord: Codable, Sendable, Identifiable {
    var id: String
    var wikiId: String
    var vector: Data
    var embeddingModel: String
    var embeddingVersion: String
    var dimensions: Int
    var createdAt: Date

    enum CodingKeys: String, CodingKey, ColumnExpression {
        case id
        case wikiId = "wiki_id"
        case vector
        case embeddingModel = "embedding_model"
        case embeddingVersion = "embedding_version"
        case dimensions
        case createdAt = "created_at"
    }

    init(wikiId: String, vector: [Float], model: String, version: String) {
        self.id = UUID().uuidString
        self.wikiId = wikiId
        self.vector = vector.withUnsafeBufferPointer { Data(buffer: $0) }
        self.embeddingModel = model
        self.embeddingVersion = version
        self.dimensions = vector.count
        self.createdAt = Date()
    }

    func vectorAsFloats() -> [Float] {
        vector.withUnsafeBytes { raw in
            Array(raw.bindMemory(to: Float.self))
        }
    }
}

nonisolated extension WikiEmbeddingRecord: FetchableRecord, PersistableRecord {
    static let databaseTableName = "wiki_embedding"
}
