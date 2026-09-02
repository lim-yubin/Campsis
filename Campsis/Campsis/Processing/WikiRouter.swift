import Accelerate
import Foundation

/// 승격 라우팅 후보: 한 메모가 갈 수 있는 기존 위키 하나와 그 신호 점수.
nonisolated struct WikiRoutingCandidate: Identifiable, Sendable, Hashable {
    let wiki: Wiki
    /// 최종 신호 = 0.7·코사인 + 0.3·태그겹침 (0~1, OW3).
    let score: Double
    /// T_high 이상이면 자동 선택 목적지(미리보기에서 체크됨).
    let autoSelected: Bool
    var id: String { wiki.id }
}

/// 메모 1개에 대한 라우팅 제안(기존 위키 후보들 + 새 위키 제안용 대표 토픽).
nonisolated struct WikiRoutingSuggestion: Identifiable, Sendable {
    let source: Source
    /// T_low 이상 후보, 점수 내림차순.
    let candidates: [WikiRoutingCandidate]
    /// 새 위키 제안 시 대표 토픽(제목 후보).
    let representativeTopic: String
    var id: String { source.id }
    /// 자동 선택(≥T_high) 후보 존재 여부.
    var hasAutoMatch: Bool { candidates.contains { $0.autoSelected } }
    /// 자동 선택 후보(N_max 상한 적용).
    var autoDestinations: [WikiRoutingCandidate] {
        Array(candidates.filter { $0.autoSelected }.prefix(WikiRouter.nMax))
    }
}

/// 정리본(메모)을 기존 위키에 매칭하거나 새 위키를 제안하는 라우터 (Phase 8.4, OW1·OW3).
///
/// 순수 DB 조회 + 벡터 연산만 수행(LLM 비호출). 임베딩은 기존 저장분을 재사용한다.
nonisolated struct WikiRouter: Sendable {
    let embeddingRepository: EmbeddingRepository
    let wikiRepository: WikiRepository
    let sourceRepository: SourceRepository

    /// 후보 제시 하한(채팅 relevanceFloor와 정렬).
    static let tLow = 0.40
    /// 한 메모의 목적지 위키 상한(재합성 비용 곱연산 방지).
    static let nMax = 3
    /// 코사인/태그 가중치.
    static let cosineWeight = 0.7
    static let tagWeight = 0.3

    /// 콜드스타트 동적 T_high: 위키가 적을수록 새 위키를 유도(OW3).
    static func tHigh(wikiCount: Int) -> Double {
        switch wikiCount {
        case 0...2: return 0.65
        case 3...4: return 0.60
        default: return 0.55
        }
    }

    /// 제목/토픽을 정규화한 매칭 키(중복 방지·새 위키 그룹핑).
    static func slug(_ topic: String) -> String {
        topic.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: "-", options: .regularExpression)
    }

    /// 선택된 메모들의 라우팅 제안을 계산한다.
    func route(_ sources: [Source]) throws -> [WikiRoutingSuggestion] {
        let wikis = try wikiRepository.fetchAll()
        let threshold = Self.tHigh(wikiCount: wikis.count)
        let wikiVectors = try wikiVectorMap(wikis)
        let wikiTopics = try wikiTopicMap(wikis)

        return sources.map { source in
            let srcVec = (try? embeddingRepository.fetch(forSourceId: source.id))?.vectorAsFloats()
            let srcTopics = Self.topics(of: source)

            var scored: [WikiRoutingCandidate] = []
            for wiki in wikis {
                var cos = 0.0
                if let srcVec, let wikiVec = wikiVectors[wiki.id] {
                    cos = Double(Self.cosine(srcVec, wikiVec))
                }
                let tag = Self.jaccard(srcTopics, wikiTopics[wiki.id] ?? [])
                let signal = Self.cosineWeight * cos + Self.tagWeight * tag
                if signal >= Self.tLow {
                    scored.append(WikiRoutingCandidate(wiki: wiki, score: signal,
                                                       autoSelected: signal >= threshold))
                }
            }
            scored.sort { $0.score > $1.score }

            let repTopic = srcTopics.first ?? source.displayTitle
            return WikiRoutingSuggestion(source: source,
                                         candidates: Array(scored.prefix(5)),
                                         representativeTopic: repTopic)
        }
    }

    // MARK: - 위키 대표 벡터/토픽

    /// 위키 id → 대표 임베딩. 페이지 임베딩 우선, 없으면 구성 메모 centroid 폴백(OW2).
    private func wikiVectorMap(_ wikis: [Wiki]) throws -> [String: [Float]] {
        let pageEmbeddings = try wikiRepository.fetchAllEmbeddings(
            model: EmbeddingService.modelName, version: EmbeddingService.embeddingVersion)
        var map: [String: [Float]] = [:]
        for e in pageEmbeddings { map[e.wikiId] = e.vectorAsFloats() }

        for wiki in wikis where map[wiki.id] == nil {
            if let centroid = try centroid(forWiki: wiki.id) {
                map[wiki.id] = centroid
            }
        }
        return map
    }

    /// 구성 메모 임베딩 평균(재합성 전 위키 폴백 대표 벡터).
    private func centroid(forWiki wikiId: String) throws -> [Float]? {
        let sourceIds = try wikiRepository.noteIds(forWiki: wikiId)
        var sum: [Float] = []
        var n = 0
        for sid in sourceIds {
            guard let vec = try embeddingRepository.fetch(forSourceId: sid)?.vectorAsFloats() else { continue }
            if sum.isEmpty { sum = [Float](repeating: 0, count: vec.count) }
            guard sum.count == vec.count else { continue }
            vDSP_vadd(sum, 1, vec, 1, &sum, 1, vDSP_Length(vec.count))
            n += 1
        }
        guard n > 0 else { return nil }
        var scale = Float(1.0 / Double(n))
        vDSP_vsmul(sum, 1, &scale, &sum, 1, vDSP_Length(sum.count))
        return sum
    }

    /// 위키 id → 대표 토픽 집합(위키 제목 + 구성 메모들의 topics 합집합).
    private func wikiTopicMap(_ wikis: [Wiki]) throws -> [String: Set<String>] {
        var map: [String: Set<String>] = [:]
        for wiki in wikis {
            var topics: Set<String> = [Self.slug(wiki.title), Self.slug(wiki.topicSlug)]
            for sid in try wikiRepository.noteIds(forWiki: wiki.id) {
                if let source = try? sourceRepository.fetch(id: sid) {
                    for t in Self.topics(of: source) { topics.insert(Self.slug(t)) }
                }
            }
            map[wiki.id] = topics
        }
        return map
    }

    // MARK: - 유틸

    /// 소스의 정리본 태그 배열(JSON) → 정규화 집합.
    static func topics(of source: Source) -> [String] {
        guard let json = source.topics,
              let data = json.data(using: .utf8),
              let arr = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return arr
    }

    /// 두 토픽 집합의 자카드 유사도(0~1).
    static func jaccard(_ a: [String], _ b: Set<String>) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        let sa = Set(a.map { slug($0) })
        let sb = Set(b.map { slug($0) })
        let inter = sa.intersection(sb).count
        let union = sa.union(sb).count
        return union > 0 ? Double(inter) / Double(union) : 0
    }

    static func cosine(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        let n = vDSP_Length(a.count)
        var dot: Float = 0
        vDSP_dotpr(a, 1, b, 1, &dot, n)
        var normA: Float = 0
        var normB: Float = 0
        vDSP_svesq(a, 1, &normA, n)
        vDSP_svesq(b, 1, &normB, n)
        let denom = sqrt(normA) * sqrt(normB)
        guard denom > 1e-9 else { return 0 }
        return dot / denom
    }
}
