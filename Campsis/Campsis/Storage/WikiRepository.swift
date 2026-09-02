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
            var w = wiki
            try w.save(db)
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
            var r = revision
            try r.insert(db)
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
            var link = NoteWikiLink(sourceId: sourceId, wikiId: wikiId, matchScore: matchScore)
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

    // MARK: - 위키 ↔ 위키 링크

    func addWikiLink(from fromWikiId: String, to toWikiId: String, weight: Double? = nil) throws {
        guard fromWikiId != toWikiId else { return }
        try dbQueue.write { db in
            var link = WikiWikiLink(fromWikiId: fromWikiId, toWikiId: toWikiId, weight: weight)
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

    // MARK: - 위키 페이지 임베딩 (OW2)

    /// 위키 임베딩 교체(기존 삭제 후 삽입).
    func saveEmbedding(_ vector: [Float], forWiki wikiId: String,
                       model: String, version: String) throws {
        try dbQueue.write { db in
            try WikiEmbeddingRecord
                .filter(Column("wiki_id") == wikiId)
                .deleteAll(db)
            var record = WikiEmbeddingRecord(wikiId: wikiId, vector: vector,
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
