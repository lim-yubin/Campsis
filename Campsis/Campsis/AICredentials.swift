import Foundation

/// AI 키를 계층적으로 해석한다 (D38, 하이브리드 배포 전략).
///
/// 우선순위:
///  1. 사용자 Keychain (BYOK) — 모든 빌드에서 최우선.
///  2. (DEBUG 전용) 로컬 `.env`의 `OPENAI_API_KEY` — 개발 편의용. 릴리즈 빌드에는 컴파일되지 않는다.
///  3. (미래) 프록시 서버 — 클라이언트는 키를 직접 갖지 않고 서버가 제작자 키를 보관한다.
///
/// 배포 바이너리에는 제작자 키가 절대 포함되지 않는다: 2번은 `#if DEBUG`로 감싸져 있고,
/// 그 소스 경로(`#filePath`)는 개발자 기기에서만 유효하다.
nonisolated enum AICredentials {
    /// 사용 가능한 OpenAI API 키. 없으면 nil.
    static var openAIKey: String? {
        if let key = KeychainHelper.openAIKey, !key.isEmpty {
            return key
        }
        #if DEBUG
        if let key = DevEnv.openAIKey, !key.isEmpty {
            return key
        }
        #endif
        return nil
    }

    /// 사용자가 직접 입력한 키(BYOK)가 있는지 여부. 설정 UI에서 사용.
    static var hasUserKey: Bool {
        (KeychainHelper.openAIKey?.isEmpty == false)
    }
}

#if DEBUG
/// 개발 빌드 전용. 저장소 루트의 `.env`에서 `KEY=VALUE`를 읽는다.
/// `.env`는 `.gitignore`에 있으며 릴리즈 빌드에는 이 코드가 포함되지 않는다.
private nonisolated enum DevEnv {
    static var openAIKey: String? {
        if let env = ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
           !env.trimmingCharacters(in: .whitespaces).isEmpty {
            return env.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value(for: "OPENAI_API_KEY")
    }

    private static func value(for key: String) -> String? {
        guard let root = repoRoot,
              let contents = try? String(contentsOf: root.appendingPathComponent(".env"), encoding: .utf8) else {
            return nil
        }
        for rawLine in contents.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.hasPrefix("#"), let eq = line.firstIndex(of: "=") else { continue }
            let name = line[..<eq].trimmingCharacters(in: .whitespaces)
            guard name == key else { continue }
            var raw = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            if raw.hasPrefix("\"") && raw.hasSuffix("\"") && raw.count >= 2 {
                raw = String(raw.dropFirst().dropLast())
            }
            return raw.isEmpty ? nil : raw
        }
        return nil
    }

    /// 이 소스 파일 경로에서 저장소 루트를 유추한다.
    /// `<repo>/Campsis/Campsis/AICredentials.swift` → `<repo>`
    private static var repoRoot: URL? {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Campsis/Campsis
            .deletingLastPathComponent() // Campsis
            .deletingLastPathComponent() // <repo>
    }
}
#endif
