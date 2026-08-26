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
        try AppPaths.ensureDirectories()
        return try AppDatabase(path: AppPaths.database.path(percentEncoded: false))
    }
}
