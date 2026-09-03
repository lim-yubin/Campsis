import Foundation
@preconcurrency import GRDB

/// Phase 8 위키 저장소. 위키 CRUD, 종합 MD 파일(진실원) 읽기/쓰기(되돌리기 스냅샷 포함),
/// 메모↔위키/위키↔위키 링크, 위키 페이지 임베딩을 다룬다.
nonisolated struct WikiRepository: Sendable {
    private let dbQueue: DatabaseQueue

    /// 위키당 보관할 되돌리기 스냅샷 최대 개수 (OW4 링버퍼).
    static let maxRevisionsPerWiki = 10

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    // MARK: - Wiki CRUD

    func save(_ wiki: inout Wiki) throws {
        wiki.updatedAt = Date()
        try dbQueue.write { [wiki] db in
            try wiki.save(db)
        }
    }

    func fetch(id: String) throws -> Wiki? {
        try dbQueue.read { db in try Wiki.fetchOne(db, key: id) }
    }

    func fetchAll() throws -> [Wiki] {
        try dbQueue.read { db in
            try Wiki.order(Wiki.Columns.updatedAt.desc).fetchAll(db)
        }
    }

    func fetch(topicSlug: String) throws -> Wiki? {
        try dbQueue.read { db in
            try Wiki.filter(Wiki.Columns.topicSlug == topicSlug).fetchOne(db)
        }
    }

    func count() throws -> Int {
        try dbQueue.read { db in try Wiki.fetchCount(db) }
    }

    func delete(_ wiki: Wiki) throws {
        _ = try dbQueue.write { db in try wiki.delete(db) }
        removeAssociatedFiles(wiki)
    }

    // MARK: - 종합 MD (진실원) + 되돌리기 스냅샷

    /// 위키 MD를 저장한다. 기존 MD가 있으면 **쓰기 직전 스냅샷**을 남긴다(OW4).
    func writeMarkdown(_ text: String, for wiki: inout Wiki,
                       reason: WikiRevisionReason,
                       addedSourceIds: [String]? = nil,
                       markedEdited: Bool = false) throws {
        try AppPaths.ensureDirectories()

        // 1. 이전 버전 스냅샷 (있을 때만).
        if let existing = readMarkdown(wiki) {
            try snapshot(existing, for: wiki, reason: reason,
                         summary: wiki.summary, addedSourceIds: addedSourceIds)
        }

        // 2. 새 MD 파일 쓰기.
        let url = AppPaths.wikiMarkdowns.appending(path: "\(wiki.id).md")
        try text.data(using: .utf8)?.write(to: url, options: .atomic)

        wiki.markdownPath = AppPaths.relativePath(from: url)
        wiki.markdownStatus = .completed
        wiki.markdownUpdatedAt = Date()
        if markedEdited { wiki.markdownEdited = true }
        try save(&wiki)

        try pruneRevisions(wikiId: wiki.id)
    }

    func readMarkdown(_ wiki: Wiki) -> String? {
        guard let path = wiki.markdownPath else { return nil }
        return try? String(contentsOf: AppPaths.absoluteURL(from: path), encoding: .utf8)
    }

    /// 현재 MD를 스냅샷 파일 + `wiki_revision` 레코드로 보관.
    private func snapshot(_ markdown: String, for wiki: Wiki,
                          reason: WikiRevisionReason, summary: String?,
                          addedSourceIds: [String]?) throws {
        let dir = AppPaths.wikiRevisions.appending(path: wiki.id, directoryHint: .isDirectory)
        let fm = FileManager.default
        if !fm.fileExists(atPath: dir.path(percentEncoded: false)) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        var revision = WikiRevision(wikiId: wiki.id, snapshotPath: "",
                                    reason: reason, summary: summary,
                                    addedSourceIds: addedSourceIds)
        let url = dir.appending(path: "\(revision.id).md")
        try markdown.data(using: .utf8)?.write(to: url, options: .atomic)
        revision.snapshotPath = AppPaths.relativePath(from: url)
        try dbQueue.write { [revision] db in
            try revision.insert(db)
        }
    }

    func revisions(forWiki wikiId: String) throws -> [WikiRevision] {
        try dbQueue.read { db in
            try WikiRevision
                .filter(WikiRevision.Columns.wikiId == wikiId)
                .order(WikiRevision.Columns.createdAt.desc)
                .fetchAll(db)
        }
    }

    /// 링버퍼 초과 스냅샷(파일+레코드) 정리.
    private func pruneRevisions(wikiId: String) throws {
        let all = try revisions(forWiki: wikiId)
        guard all.count > Self.maxRevisionsPerWiki else { return }
        let stale = all[Self.maxRevisionsPerWiki...]
        let fm = FileManager.default
        for rev in stale {
            try? fm.removeItem(at: AppPaths.absoluteURL(from: rev.snapshotPath))
        }
        let ids = stale.map(\.id)
        _ = try dbQueue.write { db in
            try WikiRevision.filter(keys: ids).deleteAll(db)
        }
    }

    // MARK: - 메모 ↔ 위키 링크

    /// 메모를 위키에 등록(멱등) 후 member_count 갱신.
    func addNote(_ sourceId: String, toWiki wikiId: String, matchScore: Double? = nil) throws {
        try dbQueue.write { db in
            let link = NoteWikiLink(sourceId: sourceId, wikiId: wikiId, matchScore: matchScore)
            try link.save(db)
        }
        try refreshMemberCount(wikiId: wikiId)
    }

    /// 메모를 위키에서 제거 후 member_count 갱신.
    func removeNote(_ sourceId: String, fromWiki wikiId: String) throws {
        _ = try dbQueue.write { db in
            try NoteWikiLink
                .filter(NoteWikiLink.Columns.sourceId == sourceId)
                .filter(NoteWikiLink.Columns.wikiId == wikiId)
                .deleteAll(db)
        }
        try refreshMemberCount(wikiId: wikiId)
    }

    func noteIds(forWiki wikiId: String) throws -> [String] {
        try dbQueue.read { db in
            try NoteWikiLink
                .filter(NoteWikiLink.Columns.wikiId == wikiId)
                .order(NoteWikiLink.Columns.addedAt.asc)
                .fetchAll(db)
                .map(\.sourceId)
        }
    }

    func wikiIds(forSource sourceId: String) throws -> [String] {
        try dbQueue.read { db in
            try NoteWikiLink
                .filter(NoteWikiLink.Columns.sourceId == sourceId)
                .fetchAll(db)
                .map(\.wikiId)
        }
    }

    /// 아직 어떤 위키에도 속하지 않은 메모 id 집합(메모함 "미주입" 구분용).
    func linkedSourceIds() throws -> Set<String> {
        try dbQueue.read { db in
            let ids = try String.fetchAll(db, sql: "SELECT DISTINCT source_id FROM note_wiki_link")
            return Set(ids)
        }
    }

    /// 메모 id → 소속 위키 제목 목록 맵(메모함 소속 위키 배지용). 한 번의 조회로 전체 구성.
    func membershipTitles() throws -> [String: [String]] {
        try dbQueue.read { db in
            let titleById = Dictionary(
                try Wiki.fetchAll(db).map { ($0.id, $0.title) },
                uniquingKeysWith: { first, _ in first }
            )
            var map: [String: [String]] = [:]
            for link in try NoteWikiLink.fetchAll(db) {
                if let title = titleById[link.wikiId] {
                    map[link.sourceId, default: []].append(title)
                }
            }
            return map
        }
    }

    /// 지정한 위키들의 `member_count`를 실제 링크 수로 재계산한다.
    /// 메모 삭제 등 FK cascade로 링크만 사라진 경우 비정규화 캐시 정합성을 복구한다.
    func refreshMemberCounts(forWikis ids: [String]) throws {
        for id in Set(ids) { try refreshMemberCount(wikiId: id) }
    }

    private func refreshMemberCount(wikiId: String) throws {
        try dbQueue.write { db in
            let count = try NoteWikiLink
                .filter(NoteWikiLink.Columns.wikiId == wikiId)
                .fetchCount(db)
            if var wiki = try Wiki.fetchOne(db, key: wikiId) {
                wiki.memberCount = count
                wiki.updatedAt = Date()
                try wiki.update(db)
            }
        }
    }

    // MARK: - 위키 병합 (Lint 중복 제안, 8.11)

    /// `sourceWikiId`의 구성 메모·백링크를 `targetWikiId`로 이관하고 source를 삭제한다.
    /// target은 병합 내용을 흡수하도록 재합성 대기(`pending`)로 표시하되, 사람이 직접
    /// 편집한 위키(`markdownEdited`)는 상태를 유지한다. 이관된(=target에 새로 추가된) 메모 id를 반환.
    @discardableResult
    func merge(sourceWikiId: String, intoWikiId targetWikiId: String) throws -> [String] {
        guard sourceWikiId != targetWikiId else { return [] }
        let sourceWiki = try fetch(id: sourceWikiId)

        let movedIds: [String] = try dbQueue.write { db in
            var moved: [String] = []

            // 1. 메모 링크 이관: target에 없는 것만 옮긴다(원본 링크는 source 삭제 시 cascade).
            let sourceLinks = try NoteWikiLink
                .filter(NoteWikiLink.Columns.wikiId == sourceWikiId)
                .fetchAll(db)
            for link in sourceLinks {
                let exists = try NoteWikiLink
                    .filter(NoteWikiLink.Columns.wikiId == targetWikiId)
                    .filter(NoteWikiLink.Columns.sourceId == link.sourceId)
                    .fetchCount(db) > 0
                if !exists {
                    var moved0 = link
                    moved0.wikiId = targetWikiId
                    try moved0.insert(db)
                    moved.append(link.sourceId)
                }
            }

            // 2. 위키 백링크 이관: source가 등장하는 링크를 target으로 치환(자기참조 제거).
            let wikiLinks = try WikiWikiLink
                .filter(WikiWikiLink.Columns.fromWikiId == sourceWikiId
                        || WikiWikiLink.Columns.toWikiId == sourceWikiId)
                .fetchAll(db)
            for link in wikiLinks {
                let from = link.fromWikiId == sourceWikiId ? targetWikiId : link.fromWikiId
                let to = link.toWikiId == sourceWikiId ? targetWikiId : link.toWikiId
                if from != to {
                    try WikiWikiLink(fromWikiId: from, toWikiId: to,
                                     weight: link.weight, kind: link.kind).save(db)
                }
            }

            // 3. source 삭제 (note_wiki_link/wiki_wiki_link/wiki_embedding FK cascade).
            if let source = try Wiki.fetchOne(db, key: sourceWikiId) {
                try source.delete(db)
            }

            // 4. target member_count 갱신 + 재합성 대기(사람 편집 위키는 보호).
            if var target = try Wiki.fetchOne(db, key: targetWikiId) {
                target.memberCount = try NoteWikiLink
                    .filter(NoteWikiLink.Columns.wikiId == targetWikiId)
                    .fetchCount(db)
                if !target.markdownEdited { target.markdownStatus = .pending }
                target.updatedAt = Date()
                try target.update(db)
            }
            return moved
        }

        // DB cascade는 파일을 지우지 않으므로 source MD/스냅샷을 수동 정리.
        if let sourceWiki { removeAssociatedFiles(sourceWiki) }
        return movedIds
    }

    // MARK: - 위키 ↔ 위키 링크

    func addWikiLink(from fromWikiId: String, to toWikiId: String, weight: Double? = nil,
                     kind: WikiLinkKind = .explicit) throws {
        guard fromWikiId != toWikiId else { return }
        try dbQueue.write { db in
            let link = WikiWikiLink(fromWikiId: fromWikiId, toWikiId: toWikiId,
                                    weight: weight, kind: kind)
            try link.save(db)
        }
    }

    func relatedWikiIds(forWiki wikiId: String) throws -> [String] {
        try dbQueue.read { db in
            try WikiWikiLink
                .filter(WikiWikiLink.Columns.fromWikiId == wikiId)
                .fetchAll(db)
                .map(\.toWikiId)
        }
    }

    /// 한 위키의 `similarity` 백링크를 통째로 교체한다(양방향).
    /// 한 트랜잭션에서 (1) wikiId가 from/to로 등장하는 기존 `similarity` 링크 삭제,
    /// (2) targets(위키 id + 가중치=코사인)로 양방향 `similarity` 링크 삽입.
    /// PK가 (from,to)라 쌍당 1행이므로, 이미 `explicit`/`comembership`/`relatedTopic`
    /// 링크가 있는 쌍은 **건드리지 않고 보존**한다(이미 관련이므로 유사도 링크 불필요).
    func replaceSimilarityLinks(forWiki wikiId: String, targets: [(wikiId: String, weight: Double)]) throws {
        try dbQueue.write { db in
            let kindValue = WikiLinkKind.similarity.rawValue
            try WikiWikiLink
                .filter(WikiWikiLink.Columns.kind == kindValue)
                .filter(WikiWikiLink.Columns.fromWikiId == wikiId
                        || WikiWikiLink.Columns.toWikiId == wikiId)
                .deleteAll(db)

            for target in targets where target.wikiId != wikiId {
                try insertSimilarityIfAbsent(db, from: wikiId, to: target.wikiId, weight: target.weight)
                try insertSimilarityIfAbsent(db, from: target.wikiId, to: wikiId, weight: target.weight)
            }
        }
    }

    /// 해당 방향 쌍에 링크가 전혀 없을 때만 `similarity` 링크를 삽입한다.
    /// (다른 출처 링크가 있으면 upsert로 덮어써 provenance/weight를 잃지 않도록 보호.)
    private func insertSimilarityIfAbsent(_ db: Database, from: String, to: String, weight: Double) throws {
        let exists = try WikiWikiLink
            .filter(WikiWikiLink.Columns.fromWikiId == from)
            .filter(WikiWikiLink.Columns.toWikiId == to)
            .fetchCount(db) > 0
        guard !exists else { return }
        try WikiWikiLink(fromWikiId: from, toWikiId: to, weight: weight, kind: .similarity).insert(db)
    }

    // MARK: - 위키 페이지 임베딩 (OW2)

    /// 위키 임베딩 교체(기존 삭제 후 삽입).
    func saveEmbedding(_ vector: [Float], forWiki wikiId: String,
                       model: String, version: String) throws {
        try dbQueue.write { db in
            try WikiEmbeddingRecord
                .filter(Column("wiki_id") == wikiId)
                .deleteAll(db)
            let record = WikiEmbeddingRecord(wikiId: wikiId, vector: vector,
                                             model: model, version: version)
            try record.insert(db)
        }
    }

    func fetchAllEmbeddings(model: String, version: String) throws -> [WikiEmbeddingRecord] {
        try dbQueue.read { db in
            try WikiEmbeddingRecord
                .filter(Column("embedding_model") == model)
                .filter(Column("embedding_version") == version)
                .fetchAll(db)
        }
    }

    // MARK: - 파일 정리

    private func removeAssociatedFiles(_ wiki: Wiki) {
        let fm = FileManager.default
        if let path = wiki.markdownPath {
            try? fm.removeItem(at: AppPaths.absoluteURL(from: path))
        }
        let revDir = AppPaths.wikiRevisions.appending(path: wiki.id, directoryHint: .isDirectory)
        try? fm.removeItem(at: revDir)
    }
}
