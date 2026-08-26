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

    private func removeAssociatedFiles(_ source: Source) {
        let fm = FileManager.default
        let paths = [source.screenshotPath, source.filePath, source.audioPath].compactMap { $0 }
        for relative in paths {
            let url = AppPaths.absoluteURL(from: relative)
            try? fm.removeItem(at: url)
        }
    }
}
