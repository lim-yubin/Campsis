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

        migrator.registerMigration("v6-title") { db in
            try db.alter(table: "source") { t in
                t.add(column: "title", .text)
            }
        }

        migrator.registerMigration("v7-markdown-edited") { db in
            try db.alter(table: "source") { t in
                t.add(column: "markdown_edited", .boolean).notNull().defaults(to: false)
            }
        }

        // Phase 8 — 메모 + LLM 위키. 위키(토픽 허브=종합 MD), 메모↔위키/위키↔위키 링크,
        // 되돌리기 스냅샷(OW4), 위키 페이지 임베딩(OW2, 별도 테이블).
        migrator.registerMigration("v8-wiki") { db in
            try db.create(table: "wiki") { t in
                t.primaryKey("id", .text)
                t.column("title", .text).notNull()
                t.column("topic_slug", .text).notNull()
                t.column("summary", .text)
                t.column("markdown_path", .text)
                t.column("markdown_status", .text).notNull().defaults(to: "pending")
                t.column("markdown_updated_at", .datetime)
                t.column("markdown_edited", .boolean).notNull().defaults(to: false)
                t.column("member_count", .integer).notNull().defaults(to: 0)
                t.column("created_at", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
                t.column("updated_at", .datetime).notNull().defaults(sql: "CURRENT_TIMESTAMP")
            }
            try db.create(index: "idx_wiki_slug", on: "wiki", columns: ["topic_slug"])

            // 메모 ↔ 위키 (다대다). 소스/위키 삭제 시 링크 자동 정리.
            try db.create(table: "note_wiki_link") { t in
                t.column("source_id", .text).notNull()
                    .references("source", onDelete: .cascade)
                t.column("wiki_id", .text).notNull()
                    .references("wiki", onDelete: .cascade)
                t.column("added_at", .datetime).notNull()
                t.column("match_score", .double)
                t.primaryKey(["source_id", "wiki_id"])
            }
            try db.create(index: "idx_note_wiki_wiki", on: "note_wiki_link", columns: ["wiki_id"])

            // 위키 ↔ 위키 (관련 토픽 백링크).
            try db.create(table: "wiki_wiki_link") { t in
                t.column("from_wiki_id", .text).notNull()
                    .references("wiki", onDelete: .cascade)
                t.column("to_wiki_id", .text).notNull()
                    .references("wiki", onDelete: .cascade)
                t.column("weight", .double)
                t.primaryKey(["from_wiki_id", "to_wiki_id"])
            }

            // 되돌리기 스냅샷 (OW4). 위키 MD 쓰기 직전 이전 버전 보관.
            try db.create(table: "wiki_revision") { t in
                t.primaryKey("id", .text)
                t.column("wiki_id", .text).notNull()
                    .references("wiki", onDelete: .cascade)
                t.column("snapshot_path", .text).notNull()
                t.column("summary", .text)
                t.column("reason", .text).notNull()
                t.column("added_source_ids", .text)
                t.column("created_at", .datetime).notNull()
            }
            try db.create(index: "idx_wiki_revision_wiki", on: "wiki_revision", columns: ["wiki_id"])

            // 위키 페이지 임베딩 (OW2). 기존 embedding 테이블은 source FK(onDelete cascade)에
            // 묶여 있어 위키 벡터를 담을 수 없으므로 동형 별도 테이블로 분리한다.
            try db.create(table: "wiki_embedding") { t in
                t.primaryKey("id", .text)
                t.column("wiki_id", .text).notNull()
                    .references("wiki", onDelete: .cascade)
                t.column("vector", .blob).notNull()
                t.column("embedding_model", .text).notNull()
                t.column("embedding_version", .text).notNull()
                t.column("dimensions", .integer).notNull()
                t.column("created_at", .datetime).notNull()
            }
            try db.create(index: "idx_wiki_embedding_wiki", on: "wiki_embedding", columns: ["wiki_id"])
            try db.create(
                index: "idx_wiki_embedding_version",
                on: "wiki_embedding",
                columns: ["embedding_model", "embedding_version"]
            )
        }
    }
}
