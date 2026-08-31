import Foundation
@preconcurrency import GRDB

nonisolated struct SourceRepository: Sendable {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    func save(_ source: inout Source) throws {
        try dbQueue.write { db in
            try source.save(db)
        }
    }

    func delete(_ source: Source) throws {
        _ = try dbQueue.write { db in
            try source.delete(db)
        }
        removeAssociatedFiles(source)
    }

    func fetchAll() throws -> [Source] {
        try dbQueue.read { db in
            try Source.order(Source.Columns.capturedAt.desc).fetchAll(db)
        }
    }

    func fetchRecent(limit: Int = 50) throws -> [Source] {
        try dbQueue.read { db in
            try Source.order(Source.Columns.capturedAt.desc).limit(limit).fetchAll(db)
        }
    }

    func fetchAll(type: SourceType) throws -> [Source] {
        try dbQueue.read { db in
            try Source
                .filter(Source.Columns.type == type.rawValue)
                .order(Source.Columns.capturedAt.desc)
                .fetchAll(db)
        }
    }

    func fetch(id: String) throws -> Source? {
        try dbQueue.read { db in
            try Source.fetchOne(db, key: id)
        }
    }

    func count() throws -> Int {
        try dbQueue.read { db in
            try Source.fetchCount(db)
        }
    }

    func fetchPending(limit: Int = 10) throws -> [Source] {
        try dbQueue.read { db in
            try Source
                .filter(Source.Columns.processingStatus == ProcessingStatus.pending.rawValue)
                .order(Source.Columns.capturedAt.asc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    func updateProcessingResult(_ source: inout Source) throws {
        try dbQueue.write { db in
            try source.update(db)
        }
    }

    func update(_ source: inout Source) throws {
        try dbQueue.write { db in
            try source.update(db)
        }
    }

    // MARK: - Markdown (진실원)

    /// MD 생성이 필요한 소스: 처리 완료됐지만 아직 MD가 없는 것.
    func fetchMarkdownPending(limit: Int = 20) throws -> [Source] {
        try dbQueue.read { db in
            try Source
                .filter(Source.Columns.processingStatus == ProcessingStatus.completed.rawValue)
                .filter(Source.Columns.markdownStatus == MarkdownStatus.pending.rawValue)
                .order(Source.Columns.capturedAt.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    /// MD 파일을 저장하고 소스의 markdown 메타데이터를 갱신한다.
    func writeMarkdown(_ text: String, for source: inout Source) throws {
        try AppPaths.ensureDirectories()
        let url = AppPaths.markdowns.appending(path: "\(source.id).md")
        try text.data(using: .utf8)?.write(to: url, options: .atomic)
        source.markdownPath = AppPaths.relativePath(from: url)
        source.markdownStatus = .completed
        source.markdownUpdatedAt = Date()
        try update(&source)
    }

    /// 저장된 MD 파일 내용을 읽는다. 없으면 nil.
    func readMarkdown(_ source: Source) -> String? {
        guard let path = source.markdownPath else { return nil }
        return try? String(contentsOf: AppPaths.absoluteURL(from: path), encoding: .utf8)
    }

    private func removeAssociatedFiles(_ source: Source) {
        let fm = FileManager.default
        let paths = [source.screenshotPath, source.filePath, source.audioPath, source.markdownPath].compactMap { $0 }
        for relative in paths {
            let url = AppPaths.absoluteURL(from: relative)
            try? fm.removeItem(at: url)
        }
    }
}
