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

// MARK: - Phase 2 Tests

struct MigrationV2Tests {
    @Test func v2MigrationAddsSummaryColumn() throws {
        let db = try makeInMemoryDatabase()
        let columns = try db.dbQueue.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(source)")
        }
        let names: [String] = columns.map { $0["name"] }
        #expect(names.contains("summary"))
        #expect(names.contains("topics"))
        #expect(names.contains("processing_attempts"))
    }
}

struct ProcessingPipelineTests {
    @Test func fetchPendingReturnsPendingSources() throws {
        let db = try makeInMemoryDatabase()
        let repo = SourceRepository(dbQueue: db.dbQueue)

        var s1 = Source(type: .selectedText, content: "Pending source")
        try repo.save(&s1)

        var s2 = Source(type: .selectedText, content: "Completed source")
        s2.processingStatus = .completed
        try repo.save(&s2)

        let pending = try repo.fetchPending()
        #expect(pending.count == 1)
        #expect(pending[0].content == "Pending source")
    }

    @Test func updateProcessingResultPersists() throws {
        let db = try makeInMemoryDatabase()
        let repo = SourceRepository(dbQueue: db.dbQueue)

        var source = Source(type: .selectedText, content: "Test")
        try repo.save(&source)

        source.processingStatus = .completed
        source.summary = "This is a test summary"
        source.topics = "[\"test\",\"unit\"]"
        source.processingAttempts = 1
        try repo.updateProcessingResult(&source)

        let fetched = try repo.fetch(id: source.id)
        #expect(fetched?.processingStatus == .completed)
        #expect(fetched?.summary == "This is a test summary")
        #expect(fetched?.topics == "[\"test\",\"unit\"]")
        #expect(fetched?.processingAttempts == 1)
    }

    @Test func processingAttemptsDefaultsToZero() throws {
        let db = try makeInMemoryDatabase()
        let repo = SourceRepository(dbQueue: db.dbQueue)

        var source = Source(type: .note, content: "New source")
        try repo.save(&source)

        let fetched = try repo.fetch(id: source.id)
        #expect(fetched?.processingAttempts == 0)
    }

    @Test func failedStatusAfterMaxAttempts() throws {
        let db = try makeInMemoryDatabase()
        let repo = SourceRepository(dbQueue: db.dbQueue)

        var source = Source(type: .selectedText, content: "Will fail")
        source.processingAttempts = 3
        source.processingStatus = .failed
        try repo.save(&source)

        let fetched = try repo.fetch(id: source.id)
        #expect(fetched?.processingStatus == .failed)
        #expect(fetched?.processingAttempts == 3)
    }
}

// MARK: - Mock MarkdownGenerator for testing

struct MockMarkdownGenerator: MarkdownGenerator {
    var shouldFail = false

    func generate(from source: Source) async throws -> GeneratedNote {
        if shouldFail {
            throw MarkdownGeneratorError.invalidResponse
        }
        let base = source.content ?? source.userNote ?? ""
        return GeneratedNote(
            title: "Note",
            summary: "Summary of: \(base.prefix(20))",
            tags: ["test", "mock"],
            markdown: "# Note\n\nSummary of: \(base.prefix(20))"
        )
    }
}

struct ProcessingQueueTests {
    @Test func processesSourceToCompletion() async throws {
        guard #available(macOS 26.0, *) else { return }
        let db = try makeInMemoryDatabase()
        let repo = SourceRepository(dbQueue: db.dbQueue)
        let embedRepo = EmbeddingRepository(dbQueue: db.dbQueue)
        let embedService = EmbeddingService()
        let queue = ProcessingQueue(repository: repo,
                                    embeddingService: embedService, embeddingRepository: embedRepo)
        await queue.setMarkdownGenerator(MockMarkdownGenerator())

        var source = Source(type: .selectedText, content: "Hello world from test")
        try repo.save(&source)

        await queue.processAllPending()
        try await Task.sleep(for: .milliseconds(500))

        let fetched = try repo.fetch(id: source.id)
        #expect(fetched?.processingStatus == .completed)
        #expect(fetched?.markdownStatus == .completed)
        #expect(fetched?.summary != nil)
        #expect(fetched?.topics != nil)
    }

    @Test func generationFailureRetriesUpToMax() async throws {
        guard #available(macOS 26.0, *) else { return }
        let db = try makeInMemoryDatabase()
        let repo = SourceRepository(dbQueue: db.dbQueue)
        let embedRepo = EmbeddingRepository(dbQueue: db.dbQueue)
        let embedService = EmbeddingService()
        let queue = ProcessingQueue(repository: repo,
                                    embeddingService: embedService, embeddingRepository: embedRepo)
        await queue.setMarkdownGenerator(MockMarkdownGenerator(shouldFail: true))

        var source = Source(type: .selectedText, content: "Controversial content")
        try repo.save(&source)

        for _ in 0..<3 {
            await queue.processAllPending()
            try await Task.sleep(for: .milliseconds(200))
        }

        let fetched = try repo.fetch(id: source.id)
        #expect(fetched?.processingStatus == .failed)
        #expect(fetched?.markdownStatus == .failed)
        #expect(fetched?.processingAttempts == 3)
    }
}

// MARK: - Phase 8 Wiki (8.1 데이터 모델)

struct WikiMigrationTests {
    @Test func v8CreatesWikiTables() throws {
        let db = try makeInMemoryDatabase()
        let tables = try db.dbQueue.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table'")
        }
        #expect(tables.contains("wiki"))
        #expect(tables.contains("note_wiki_link"))
        #expect(tables.contains("wiki_wiki_link"))
        #expect(tables.contains("wiki_revision"))
        #expect(tables.contains("wiki_embedding"))
    }

    @Test func wikiTableHasExpectedColumns() throws {
        let db = try makeInMemoryDatabase()
        let columns = try db.dbQueue.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(wiki)")
        }
        let names: [String] = columns.map { $0["name"] }
        #expect(names.contains("topic_slug"))
        #expect(names.contains("markdown_path"))
        #expect(names.contains("markdown_edited"))
        #expect(names.contains("member_count"))
    }
}

struct WikiRepositoryTests {
    @Test func saveAndFetch() throws {
        let db = try makeInMemoryDatabase()
        let repo = WikiRepository(dbQueue: db.dbQueue)

        var wiki = Wiki(title: "생산성", topicSlug: "productivity", summary: "요약")
        try repo.save(&wiki)

        let fetched = try repo.fetch(id: wiki.id)
        #expect(fetched?.title == "생산성")
        #expect(fetched?.topicSlug == "productivity")
        #expect(fetched?.memberCount == 0)
        #expect(try repo.fetch(topicSlug: "productivity")?.id == wiki.id)
    }

    @Test func addAndRemoveNoteUpdatesMemberCount() throws {
        let db = try makeInMemoryDatabase()
        let wikiRepo = WikiRepository(dbQueue: db.dbQueue)
        let sourceRepo = SourceRepository(dbQueue: db.dbQueue)

        var wiki = Wiki(title: "회의록", topicSlug: "meetings")
        try wikiRepo.save(&wiki)

        var s1 = Source(type: .note, content: "메모1")
        var s2 = Source(type: .note, content: "메모2")
        try sourceRepo.save(&s1)
        try sourceRepo.save(&s2)

        try wikiRepo.addNote(s1.id, toWiki: wiki.id, matchScore: 0.7)
        try wikiRepo.addNote(s2.id, toWiki: wiki.id)
        #expect(try wikiRepo.fetch(id: wiki.id)?.memberCount == 2)
        #expect(try wikiRepo.noteIds(forWiki: wiki.id).count == 2)
        #expect(try wikiRepo.wikiIds(forSource: s1.id) == [wiki.id])
        #expect(try wikiRepo.linkedSourceIds().contains(s1.id))

        try wikiRepo.removeNote(s1.id, fromWiki: wiki.id)
        #expect(try wikiRepo.fetch(id: wiki.id)?.memberCount == 1)
    }

    @Test func addNoteIsIdempotent() throws {
        let db = try makeInMemoryDatabase()
        let wikiRepo = WikiRepository(dbQueue: db.dbQueue)
        let sourceRepo = SourceRepository(dbQueue: db.dbQueue)

        var wiki = Wiki(title: "T", topicSlug: "t")
        try wikiRepo.save(&wiki)
        var s = Source(type: .note, content: "메모")
        try sourceRepo.save(&s)

        try wikiRepo.addNote(s.id, toWiki: wiki.id)
        try wikiRepo.addNote(s.id, toWiki: wiki.id)
        #expect(try wikiRepo.fetch(id: wiki.id)?.memberCount == 1)
    }

    @Test func deletingWikiCascadesLinks() throws {
        let db = try makeInMemoryDatabase()
        let wikiRepo = WikiRepository(dbQueue: db.dbQueue)
        let sourceRepo = SourceRepository(dbQueue: db.dbQueue)

        var wiki = Wiki(title: "T", topicSlug: "t")
        try wikiRepo.save(&wiki)
        var s = Source(type: .note, content: "메모")
        try sourceRepo.save(&s)
        try wikiRepo.addNote(s.id, toWiki: wiki.id)

        try wikiRepo.delete(wiki)
        #expect(try wikiRepo.wikiIds(forSource: s.id).isEmpty)
    }

    @Test func wikiLinkRoundtrip() throws {
        let db = try makeInMemoryDatabase()
        let repo = WikiRepository(dbQueue: db.dbQueue)

        var a = Wiki(title: "A", topicSlug: "a")
        var b = Wiki(title: "B", topicSlug: "b")
        try repo.save(&a)
        try repo.save(&b)

        try repo.addWikiLink(from: a.id, to: b.id, weight: 0.5)
        #expect(try repo.relatedWikiIds(forWiki: a.id) == [b.id])
    }

    @Test func embeddingSaveReplacesAndFetches() throws {
        let db = try makeInMemoryDatabase()
        let repo = WikiRepository(dbQueue: db.dbQueue)

        var wiki = Wiki(title: "T", topicSlug: "t")
        try repo.save(&wiki)

        try repo.saveEmbedding([0.1, 0.2, 0.3], forWiki: wiki.id, model: "bge-m3", version: "1")
        try repo.saveEmbedding([0.4, 0.5, 0.6], forWiki: wiki.id, model: "bge-m3", version: "1")

        let records = try repo.fetchAllEmbeddings(model: "bge-m3", version: "1")
        #expect(records.count == 1)  // 교체됨
        #expect(records.first?.vectorAsFloats().count == 3)
    }
}

@Suite struct WikiRouterTests {
    @Test func tHighScalesWithWikiCount() {
        #expect(WikiRouter.tHigh(wikiCount: 0) == 0.65)
        #expect(WikiRouter.tHigh(wikiCount: 2) == 0.65)
        #expect(WikiRouter.tHigh(wikiCount: 3) == 0.60)
        #expect(WikiRouter.tHigh(wikiCount: 4) == 0.60)
        #expect(WikiRouter.tHigh(wikiCount: 5) == 0.55)
        #expect(WikiRouter.tHigh(wikiCount: 100) == 0.55)
    }

    @Test func slugNormalizes() {
        #expect(WikiRouter.slug("  Deep  Work ") == "deep-work")
        #expect(WikiRouter.slug("생산성") == "생산성")
    }

    @Test func jaccardOverlap() {
        #expect(WikiRouter.jaccard([], []) == 0)
        #expect(WikiRouter.jaccard(["a", "b"], ["a", "b"]) == 1.0)
        // 교집합 1(a), 합집합 3(a,b,c) → 1/3
        let j = WikiRouter.jaccard(["a", "b"], ["a", "c"])
        #expect(abs(j - (1.0 / 3.0)) < 1e-9)
    }

    /// 위키가 없으면 모든 메모가 후보 없음 → 새 위키 제안(대표 토픽).
    @Test func coldStartProposesNewWiki() throws {
        let db = try makeInMemoryDatabase()
        let router = WikiRouter(
            embeddingRepository: EmbeddingRepository(dbQueue: db.dbQueue),
            wikiRepository: WikiRepository(dbQueue: db.dbQueue),
            sourceRepository: SourceRepository(dbQueue: db.dbQueue))

        let sourceRepo = SourceRepository(dbQueue: db.dbQueue)
        var s = Source(type: .note, content: "딥워크 정리")
        s.topics = "[\"딥워크\",\"생산성\"]"
        try sourceRepo.save(&s)

        let suggestions = try router.route([s])
        #expect(suggestions.count == 1)
        #expect(suggestions[0].candidates.isEmpty)
        #expect(suggestions[0].hasAutoMatch == false)
        #expect(suggestions[0].representativeTopic == "딥워크")
    }
}

private func makeInMemoryDatabase() throws -> AppDatabase {
    try AppDatabase(path: ":memory:")
}
