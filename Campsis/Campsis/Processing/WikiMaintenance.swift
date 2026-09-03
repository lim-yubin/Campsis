import Foundation

/// 위키 유지보수(Lint) 제안의 종류 (Phase 8.11, §8).
nonisolated enum LintKind: String, Sendable {
    case duplicate   // 중복 위키 → 병합 제안
    case orphan      // 고아/빈약 위키(구성 메모 ≤ 1) → 정리/삭제 제안
}

/// 비파괴 제안 카드 1개. `id`는 dismiss 쿨다운 키로도 쓰인다.
nonisolated struct LintSuggestion: Sendable, Identifiable, Hashable {
    let id: String
    let kind: LintKind
    /// 중복: 유지할 위키(구성 메모가 더 많은 쪽). 고아: 대상 위키.
    let primaryWikiId: String
    /// 중복: primary에 합칠 위키. 고아: nil.
    let secondaryWikiId: String?
    let title: String
    let message: String
}

/// 위키 Lint 엔진 (§8, OW5). **LLM 비호출** — 중복은 벡터/slug, 고아는 DB로만 판정한다.
/// 결과는 비파괴 제안이며, 실행(병합/삭제)은 사용자 승인 후 UI에서 수행한다.
nonisolated struct WikiMaintenance: Sendable {
    let wikiRepository: WikiRepository

    /// 위키↔위키 병합 제안 임계값(OW3 T_merge). 파괴적이라 보수적 고값.
    static let tMerge: Float = 0.80

    /// 전체 위키를 점검해 제안 목록을 만든다(dismiss 필터는 호출부에서).
    func scan() -> [LintSuggestion] {
        let wikis = (try? wikiRepository.fetchAll()) ?? []
        guard wikis.count > 0 else { return [] }

        var out: [LintSuggestion] = []
        out.append(contentsOf: duplicateSuggestions(wikis))
        out.append(contentsOf: orphanSuggestions(wikis))
        return out
    }

    // MARK: - 중복 위키

    private func duplicateSuggestions(_ wikis: [Wiki]) -> [LintSuggestion] {
        guard wikis.count >= 2 else { return [] }

        let records = (try? wikiRepository.fetchAllEmbeddings(
            model: EmbeddingService.modelName,
            version: EmbeddingService.embeddingVersion)) ?? []
        let vectorById = Dictionary(records.map { ($0.wikiId, $0.vectorAsFloats()) },
                                    uniquingKeysWith: { first, _ in first })

        var out: [LintSuggestion] = []
        var seenPairs = Set<String>()
        for i in 0..<wikis.count {
            for j in (i + 1)..<wikis.count {
                let a = wikis[i], b = wikis[j]
                let duplicate: Bool
                if a.topicSlug == b.topicSlug {
                    duplicate = true
                } else if let va = vectorById[a.id], let vb = vectorById[b.id] {
                    duplicate = cosine(va, vb) >= Self.tMerge
                } else {
                    duplicate = false
                }
                guard duplicate else { continue }

                let key = [a.id, b.id].sorted().joined(separator: "|")
                guard seenPairs.insert(key).inserted else { continue }

                // 구성 메모가 많은 쪽을 유지(primary), 적은 쪽을 합침(secondary).
                let (primary, secondary) = a.memberCount >= b.memberCount ? (a, b) : (b, a)
                out.append(LintSuggestion(
                    id: "dup:\(key)",
                    kind: .duplicate,
                    primaryWikiId: primary.id,
                    secondaryWikiId: secondary.id,
                    title: "비슷한 위키",
                    message: "‘\(secondary.title)’와(과) ‘\(primary.title)’이(가) 많이 겹쳐요. 하나로 합칠까요?"))
            }
        }
        return out
    }

    // MARK: - 고아 위키

    /// 구성 메모가 **0개**인 위키만 제안한다. 메모 1개 위키는 콜드스타트에서
    /// 사용자가 의도적으로 만들 수 있어(§11) 잔소리를 피한다.
    private func orphanSuggestions(_ wikis: [Wiki]) -> [LintSuggestion] {
        wikis.filter { $0.memberCount == 0 }.map { wiki in
            LintSuggestion(
                id: "orphan:\(wiki.id)",
                kind: .orphan,
                primaryWikiId: wiki.id,
                secondaryWikiId: nil,
                title: "빈 위키",
                message: "‘\(wiki.title)’에 구성 메모가 없어요. 정리하거나 삭제할까요?")
        }
    }

    private func cosine(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0, na: Float = 0, nb: Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            na += a[i] * a[i]
            nb += b[i] * b[i]
        }
        let denom = (na.squareRoot() * nb.squareRoot())
        return denom > 0 ? dot / denom : 0
    }
}

/// dismiss한 Lint 제안의 재알림 쿨다운(§8 "알림 절제"). UserDefaults 기반.
nonisolated enum LintDismissStore {
    /// dismiss 후 재알림까지의 쿨다운(14일).
    static let cooldown: TimeInterval = 60 * 60 * 24 * 14
    private static let prefix = "lint.dismiss."

    static func isDismissed(_ id: String, now: Date = Date()) -> Bool {
        guard let date = UserDefaults.standard.object(forKey: prefix + id) as? Date else { return false }
        return now.timeIntervalSince(date) < cooldown
    }

    static func dismiss(_ id: String, now: Date = Date()) {
        UserDefaults.standard.set(now, forKey: prefix + id)
    }
}
