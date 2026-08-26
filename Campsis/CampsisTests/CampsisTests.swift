import Testing
import Foundation
import GRDB
@testable import Campsis

struct AppPathsTests {
    @Test func applicationSupportPathContainsCampsis() {
        let path = AppPaths.applicationSupport.path(percentEncoded: false)
        #expect(path.contains("Campsis"))
    }

    @Test func relativePathRoundtrip() {
        let relative = "screenshots/test.png"
        let absolute = AppPaths.absoluteURL(from: relative)
        let back = AppPaths.relativePath(from: absolute)
        #expect(back == relative)
    }

    @Test func ensureDirectoriesCreates() throws {
        let fm = FileManager.default
        try AppPaths.ensureDirectories()
        #expect(fm.fileExists(atPath: AppPaths.screenshots.path(percentEncoded: false)))
    }
}

struct MigrationTests {
    @Test func v1MigrationCreatesSourceTable() throws {
        let db = try makeInMemoryDatabase()
        let tables = try db.dbQueue.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table'")
        }
        #expect(tables.contains("source"))
    }

    @Test func v1SourceTableHasExpectedColumns() throws {
        let db = try makeInMemoryDatabase()
        let columns = try db.dbQueue.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(source)")
        }
        let names: [String] = columns.map { $0["name"] }
        #expect(names.contains("id"))
        #expect(names.contains("type"))
        #expect(names.contains("content"))
        #expect(names.contains("screenshot_path"))
        #expect(names.contains("user_note"))
        #expect(names.contains("captured_at"))
        #expect(names.contains("processing_status"))
    }
}

struct SourceRepositoryTests {
    @Test func saveAndFetch() throws {
        let db = try makeInMemoryDatabase()
        let repo = SourceRepository(dbQueue: db.dbQueue)

        var source = Source(type: .selectedText, content: "Hello world", application: "Safari")
        try repo.save(&source)

        let fetched = try repo.fetch(id: source.id)
        #expect(fetched != nil)
        #expect(fetched?.content == "Hello world")
        #expect(fetched?.application == "Safari")
        #expect(fetched?.type == .selectedText)
    }

    @Test func deleteRemovesRecord() throws {
        let db = try makeInMemoryDatabase()
        let repo = SourceRepository(dbQueue: db.dbQueue)

        var source = Source(type: .note, content: "Test note")
        try repo.save(&source)
        #expect(try repo.count() == 1)

        try repo.delete(source)
        #expect(try repo.count() == 0)
    }

    @Test func fetchRecentReturnsNewestFirst() throws {
        let db = try makeInMemoryDatabase()
        let repo = SourceRepository(dbQueue: db.dbQueue)

        var s1 = Source(type: .selectedText, content: "First")
        s1.capturedAt = Date(timeIntervalSince1970: 1000)
        try repo.save(&s1)

        var s2 = Source(type: .selectedText, content: "Second")
        s2.capturedAt = Date(timeIntervalSince1970: 2000)
        try repo.save(&s2)

        let recent = try repo.fetchRecent(limit: 10)
        #expect(recent.count == 2)
        #expect(recent[0].content == "Second")
        #expect(recent[1].content == "First")
    }

    @Test func deleteRemovesAssociatedFile() throws {
        let db = try makeInMemoryDatabase()
        let repo = SourceRepository(dbQueue: db.dbQueue)

        let fm = FileManager.default
        try AppPaths.ensureDirectories()
        let testFile = AppPaths.screenshots.appending(path: "test-delete-\(UUID().uuidString).png")
        try Data("fake".utf8).write(to: testFile)

        let relativePath = AppPaths.relativePath(from: testFile)
        var source = Source(type: .screenshot, screenshotPath: relativePath)
        try repo.save(&source)

        #expect(fm.fileExists(atPath: testFile.path(percentEncoded: false)))
        try repo.delete(source)
        #expect(!fm.fileExists(atPath: testFile.path(percentEncoded: false)))
    }
}

private func makeInMemoryDatabase() throws -> AppDatabase {
    try AppDatabase(path: ":memory:")
}
