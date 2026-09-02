import Foundation

nonisolated enum AppPaths {
    private static let appName = "Campsis"

    static let applicationSupport: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: appName, directoryHint: .isDirectory)
    }()

    static let database: URL = applicationSupport.appending(path: "campsis.db")

    static let screenshots: URL = applicationSupport.appending(path: "screenshots", directoryHint: .isDirectory)

    static let files: URL = applicationSupport.appending(path: "files", directoryHint: .isDirectory)

    static let audio: URL = applicationSupport.appending(path: "audio", directoryHint: .isDirectory)

    static let markdowns: URL = applicationSupport.appending(path: "markdowns", directoryHint: .isDirectory)

    /// 위키 종합 MD 진실원 (Phase 8).
    static let wikiMarkdowns: URL = applicationSupport.appending(path: "wiki_markdowns", directoryHint: .isDirectory)

    /// 위키 되돌리기 스냅샷 (OW4). 하위에 {wikiId}/ 디렉터리로 분류.
    static let wikiRevisions: URL = applicationSupport.appending(path: "wiki_revisions", directoryHint: .isDirectory)

    private static var basePath: String {
        let p = applicationSupport.path(percentEncoded: false)
        return p.hasSuffix("/") ? p : p + "/"
    }

    static func ensureDirectories() throws {
        let fm = FileManager.default
        for dir in [applicationSupport, screenshots, files, audio, markdowns, wikiMarkdowns, wikiRevisions] {
            if !fm.fileExists(atPath: dir.path(percentEncoded: false)) {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
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
        applicationSupport.appending(path: relativePath)
    }
}
