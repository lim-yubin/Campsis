import Foundation

/// 승격 실행 요청(라우팅 미리보기에서 사용자가 확정한 목적지들).
nonisolated struct WikiPromotionRequest: Sendable {
    struct Destination: Sendable {
        /// 기존 위키면 그 id, 새 위키면 nil.
        let existingWikiId: String?
        /// 새 위키 제목(existingWikiId == nil일 때).
        let newTitle: String?
        /// 이 목적지에 넣을 메모 id들.
        let sourceIds: [String]
        /// sourceId → 매칭 점수(감사·튜닝용, OW3).
        let scores: [String: Double]
    }
    let destinations: [Destination]
}

/// 승격 실행 결과(8.6 재합성이 소비: 어떤 위키에 어떤 메모가 새로 추가됐는지).
nonisolated struct WikiPromotionResult: Sendable {
    /// 이번 배치로 새 구성원이 생긴 위키 id → 새로 추가된 메모 id들.
    let addedByWiki: [String: [String]]
    /// 새로 생성된 위키 id들.
    let createdWikiIds: [String]
    var touchedWikiIds: [String] { Array(addedByWiki.keys) }
}

/// 승격 실행기 (Phase 8.5, 플로우 D.1).
///
/// 선택 메모를 목적지 위키의 구성원으로 **즉시 등록**하고, 배치 내 공동 소속(co-membership)
/// 위키 간 백링크를 만든다. 종합 MD 재작성(D.2)은 8.6 재합성이 담당하며,
/// 이 단계는 새 위키를 `pending` 상태로 만들어 재합성 대기임을 표시한다.
nonisolated struct WikiPromoter: Sendable {
    let wikiRepository: WikiRepository

    /// 목적지들을 실행하고, 새 구성원 매핑·생성 위키를 반환한다.
    @discardableResult
    func execute(_ request: WikiPromotionRequest) throws -> WikiPromotionResult {
        var addedByWiki: [String: [String]] = [:]
        var createdWikiIds: [String] = []
        /// sourceId → 이번 배치에서 편입된 위키 id들(백링크용).
        var wikisBySource: [String: [String]] = [:]

        for dest in request.destinations {
            guard !dest.sourceIds.isEmpty else { continue }
            let wikiId = try resolveWikiId(dest, createdWikiIds: &createdWikiIds)

            for sid in dest.sourceIds {
                try wikiRepository.addNote(sid, toWiki: wikiId, matchScore: dest.scores[sid])
                addedByWiki[wikiId, default: []].append(sid)
                wikisBySource[sid, default: []].append(wikiId)
            }
        }

        // 공동 소속 백링크: 한 메모가 여러 위키로 갔으면 그 위키들끼리 관련(양방향).
        for (_, wikiIds) in wikisBySource where wikiIds.count > 1 {
            for a in wikiIds {
                for b in wikiIds where a != b {
                    try wikiRepository.addWikiLink(from: a, to: b, weight: 1.0)
                }
            }
        }

        return WikiPromotionResult(addedByWiki: addedByWiki, createdWikiIds: createdWikiIds)
    }

    /// 기존 위키면 그 id, 새 위키면 slug 중복 확인 후 재사용 또는 생성.
    private func resolveWikiId(_ dest: WikiPromotionRequest.Destination,
                               createdWikiIds: inout [String]) throws -> String {
        if let id = dest.existingWikiId { return id }

        let title = (dest.newTitle?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap {
            $0.isEmpty ? nil : $0
        } ?? "새 위키"
        let slug = WikiRouter.slug(title)

        // 배치 밖에서 이미 같은 토픽 위키가 있으면 재사용(중복 방지).
        if let existing = try wikiRepository.fetch(topicSlug: slug) {
            return existing.id
        }

        var wiki = Wiki(title: title, topicSlug: slug)
        wiki.markdownStatus = .pending   // 재합성(8.6) 대기.
        try wikiRepository.save(&wiki)
        createdWikiIds.append(wiki.id)
        return wiki.id
    }
}
