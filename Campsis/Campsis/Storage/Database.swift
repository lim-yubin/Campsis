import Foundation
@preconcurrency import GRDB

nonisolated final class AppDatabase: Sendable {
    let dbQueue: DatabaseQueue

    init(path: String) throws {
        var config = Configuration()
        #if DEBUG
        config.prepareDatabase { db in
            db.trace { print("SQL: \($0)") }
        }
        #endif

        dbQueue = try DatabaseQueue(path: path, configuration: config)
        try migrator.migrate(dbQueue)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif
        AppMigrations.register(&migrator)
        return migrator
    }

    static func makeDefault() throws -> AppDatabase {
        // DB를 새 위치에서 열기 전에, 구 데이터 루트에서 일회성 이전을 수행한다.
        AppPaths.migrateToDocumentsIfNeeded()
        try AppPaths.ensureDirectories()
        return try AppDatabase(path: AppPaths.database.path(percentEncoded: false))
    }
}
