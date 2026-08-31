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

        migrator.registerMigration("v2-processing") { db in
            try db.alter(table: "source") { t in
                t.add(column: "summary", .text)
                t.add(column: "topics", .text)
                t.add(column: "processing_attempts", .integer).notNull().defaults(to: 0)
            }
        }

        migrator.registerMigration("v3-embedding") { db in
            try db.create(table: "embedding") { t in
                t.primaryKey("id", .text)
                t.column("source_id", .text).notNull()
                    .references("source", onDelete: .cascade)
                t.column("vector", .blob).notNull()
                t.column("embedding_model", .text).notNull()
                t.column("embedding_version", .text).notNull()
                t.column("dimensions", .integer).notNull()
                t.column("created_at", .datetime).notNull()
            }
            try db.create(
                index: "idx_embedding_source",
                on: "embedding",
                columns: ["source_id"]
            )
            try db.create(
                index: "idx_embedding_version",
                on: "embedding",
                columns: ["embedding_model", "embedding_version"]
            )
        }

        migrator.registerMigration("v4-chat") { db in
            try db.create(table: "conversation") { t in
                t.primaryKey("id", .text)
                t.column("title", .text).notNull()
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
            }

            try db.create(table: "message") { t in
                t.primaryKey("id", .text)
                t.column("conversation_id", .text).notNull()
                    .references("conversation", onDelete: .cascade)
                t.column("role", .text).notNull()
                t.column("content", .text).notNull()
                t.column("source_ids", .text)
                t.column("created_at", .datetime).notNull()
            }
            try db.create(
                index: "idx_message_conversation",
                on: "message",
                columns: ["conversation_id"]
            )
        }

        migrator.registerMigration("v5-markdown") { db in
            try db.alter(table: "source") { t in
                t.add(column: "markdown_path", .text)
                t.add(column: "markdown_status", .text).notNull().defaults(to: "pending")
                t.add(column: "markdown_updated_at", .datetime)
            }
        }
    }
}
