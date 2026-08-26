@preconcurrency import GRDB

nonisolated enum AppMigrations {
    static func register(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1-source") { db in
            try db.create(table: "source") { t in
                t.primaryKey("id", .text)
                t.column("type", .text).notNull()
                t.column("content", .text)
                t.column("screenshot_path", .text)
                t.column("file_path", .text)
                t.column("audio_path", .text)
                t.column("ocr_text", .text)
                t.column("transcript", .text)
                t.column("user_note", .text)
                t.column("application", .text)
                t.column("window_title", .text)
                t.column("url", .text)
                t.column("captured_at", .datetime).notNull()
                t.column("created_at", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("processing_status", .text).notNull().defaults(to: "pending")
            }
        }
    }
}
