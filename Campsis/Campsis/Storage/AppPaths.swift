import Foundation

nonisolated enum AppPaths {
    private static let appName = "Campsis"

    /// 데이터 루트: ~/Documents/Campsis.
    /// 사용자가 파인더로 직접 원본·정리본·스크린샷을 열람할 수 있고, 샌드박스 앱(미리보기)이
    /// ~/Library/Application Support와 달리 제자리 편집·저장할 수 있는 위치.
    static let dataRoot: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appending(path: appName, directoryHint: .isDirectory)
    }()

    /// 구(舊) 데이터 루트: ~/Library/Application Support/Campsis (마이그레이션 원본).
    static let legacyApplicationSupport: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: appName, directoryHint: .isDirectory)
    }()

    static let database: URL = dataRoot.appending(path: "campsis.db")

    static let screenshots: URL = dataRoot.appending(path: "screenshots", directoryHint: .isDirectory)

    static let files: URL = dataRoot.appending(path: "files", directoryHint: .isDirectory)

    static let audio: URL = dataRoot.appending(path: "audio", directoryHint: .isDirectory)

    static let markdowns: URL = dataRoot.appending(path: "markdowns", directoryHint: .isDirectory)

    /// 위키 종합 MD 진실원 (Phase 8).
    static let wikiMarkdowns: URL = dataRoot.appending(path: "wiki_markdowns", directoryHint: .isDirectory)

    /// 위키 되돌리기 스냅샷 (OW4). 하위에 {wikiId}/ 디렉터리로 분류.
    static let wikiRevisions: URL = dataRoot.appending(path: "wiki_revisions", directoryHint: .isDirectory)

    private static var basePath: String {
        let p = dataRoot.path(percentEncoded: false)
        return p.hasSuffix("/") ? p : p + "/"
    }

    static func ensureDirectories() throws {
        let fm = FileManager.default
        for dir in [dataRoot, screenshots, files, audio, markdowns, wikiMarkdowns, wikiRevisions] {
            if !fm.fileExists(atPath: dir.path(percentEncoded: false)) {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }

    /// 구 데이터 루트(~/Library/Application Support/Campsis)의 사용자 데이터를
    /// 새 루트(~/Documents/Campsis)로 일회성 이전한다. DB 오픈 이전에 호출해야 한다.
    /// - 이동 대상: campsis.db(+wal/shm), screenshots/, files/, audio/, markdowns/, wiki_markdowns/, wiki_revisions/
    /// - 이동 제외: Models/ (대용량 내부 에셋 → 구 위치 유지)
    /// - 멱등: 대상에 이미 존재하는 항목은 건너뛴다.
    static func migrateToDocumentsIfNeeded() {
        let fm = FileManager.default
        let old = legacyApplicationSupport
        guard fm.fileExists(atPath: old.path(percentEncoded: false)) else { return }

        // 새 루트 생성
        try? fm.createDirectory(at: dataRoot, withIntermediateDirectories: true)

        let items = [
            "campsis.db", "campsis.db-wal", "campsis.db-shm",
            "screenshots", "files", "audio",
            "markdowns", "wiki_markdowns", "wiki_revisions"
        ]

        for name in items {
            let src = old.appending(path: name)
            let dst = dataRoot.appending(path: name)
            guard fm.fileExists(atPath: src.path(percentEncoded: false)) else { continue }
            guard !fm.fileExists(atPath: dst.path(percentEncoded: false)) else { continue }
            do {
                try fm.moveItem(at: src, to: dst)
            } catch {
                NSLog("[Campsis] Data migration failed for \(name): \(error)")
            }
        }
    }

    static func relativePath(from absoluteURL: URL) -> String {
        let abs = absoluteURL.path(percentEncoded: false)
        if abs.hasPrefix(basePath) {
            return String(abs.dropFirst(basePath.count))
        }
        return abs
    }

    static func absoluteURL(from relativePath: String) -> URL {
        dataRoot.appending(path: relativePath)
    }

    /// 원본 파일을 외부 앱(미리보기 등)에서 제자리 편집할 수 있도록 준비한다.
    /// - `com.apple.quarantine` 격리 속성 제거: 격리된 파일은 미리보기에서
    ///   읽기 전용으로 열려 복제본만 생성된다.
    /// - 소유자 쓰기 권한 보장: 혹시 읽기 전용으로 저장된 경우를 대비.
    static func prepareForInPlaceEditing(_ url: URL) {
        let fm = FileManager.default
        let path = url.path(percentEncoded: false)
        guard fm.fileExists(atPath: path) else { return }

        // 격리 속성 제거 (없으면 무시)
        url.withUnsafeFileSystemRepresentation { cPath in
            guard let cPath else { return }
            _ = removexattr(cPath, "com.apple.quarantine", 0)
        }

        // 소유자 쓰기 권한 보장
        if let attrs = try? fm.attributesOfItem(atPath: path),
           let perm = attrs[.posixPermissions] as? NSNumber {
            let withOwnerWrite = perm.uint16Value | 0o200
            if withOwnerWrite != perm.uint16Value {
                try? fm.setAttributes([.posixPermissions: NSNumber(value: withOwnerWrite)], ofItemAtPath: path)
            }
        }
    }
}
