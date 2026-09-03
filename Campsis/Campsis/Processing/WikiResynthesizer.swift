import Foundation

/// 증분 재합성 파이프라인 (Phase 8.6, 플로우 D.2).
///
/// 승격 결과(`WikiPromotionResult`)를 받아 **위키별 1회** 재합성한다.
/// `[현재 위키 페이지 + 새로 추가된 메모들]`만 Luna에 전달(증분) → 비용 선형.
/// 백그라운드 실행이며 위키 `markdown_status`로 "정리 중" 상태를 노출한다.
actor WikiResynthesizer {
    private let sourceRepository: SourceRepository
    private let wikiRepository: WikiRepository
    private let embeddingService: EmbeddingService
    private let maxNoteBodyChars = 4000
    private var synthesizer: WikiSynthesizer?

    init(sourceRepository: SourceRepository, wikiRepository: WikiRepository,
         embeddingService: EmbeddingService) {
        self.sourceRepository = sourceRepository
        self.wikiRepository = wikiRepository
        self.embeddingService = embeddingService
    }

    /// Luna 백엔드 주입(설정/키 변경 시). nil이면 재합성 스킵(위키는 pending 유지).
    func setSynthesizer(_ synthesizer: WikiSynthesizer?) {
        self.synthesizer = synthesizer
    }

    /// 사용자가 위키를 직접 편집한 뒤(8.10) 검색 반영을 위해 페이지만 재임베딩한다.
    /// LLM 재합성 없이 현재 저장된 MD로만 임베딩을 갱신(비용 없음).
    func reembedEditedWiki(wikiId: String) async {
        guard let wiki = try? wikiRepository.fetch(id: wikiId),
              let markdown = wikiRepository.readMarkdown(wiki), !markdown.isEmpty else { return }
        await embedWiki(wiki, summary: wiki.summary, markdown: markdown)
        linkSimilarWikis(wikiId: wikiId)
    }

    /// 승격 배치의 모든 대상 위키를 순차 재합성(비용/레이트 통제).
    func resynthesize(_ result: WikiPromotionResult) async {
        for (wikiId, added) in result.addedByWiki {
            await resynthesizeWiki(wikiId: wikiId, addedSourceIds: added)
        }
    }

    /// 위키 1개 재합성: 페이지 재작성 → 저장(스냅샷) → 재임베딩 → 관련 위키 백링크.
    func resynthesizeWiki(wikiId: String, addedSourceIds: [String]) async {
        guard let synthesizer else { return }   // 키 없음 → pending 유지, 다음 트리거 때.
        guard var wiki = try? wikiRepository.fetch(id: wikiId) else { return }

        // 사람 편집 보호(§10, 8.10 선반영): 수동 편집 위키는 자동 덮어쓰기 금지.
        if wiki.markdownEdited {
            NSLog("[Campsis] Skip resynthesis (user-edited): \(wikiId)")
            return
        }

        let hadContent = wikiRepository.readMarkdown(wiki) != nil
        wiki.markdownStatus = .processing
        try? wikiRepository.save(&wiki)

        let currentMarkdown = wikiRepository.readMarkdown(wiki)
        let notes = buildNoteInputs(addedSourceIds)

        guard !notes.isEmpty || currentMarkdown != nil else {
            wiki.markdownStatus = hadContent ? .completed : .failed
            try? wikiRepository.save(&wiki)
            return
        }

        do {
            let out = try await synthesizer.synthesize(
                title: wiki.title, currentMarkdown: currentMarkdown, newNotes: notes)

            // writeMarkdown이 쓰기 직전 스냅샷(OW4) + status=.completed + updated_at 갱신.
            try wikiRepository.writeMarkdown(out.markdown, for: &wiki,
                                             reason: .resynthesis,
                                             addedSourceIds: addedSourceIds)
            if let summary = out.summary {
                wiki.summary = summary
                try? wikiRepository.save(&wiki)
            }

            await embedWiki(wiki, summary: out.summary, markdown: out.markdown)
            applyRelatedTopics(out.relatedTopics, for: wiki)
            linkSimilarWikis(wikiId: wikiId)
            NSLog("[Campsis] Resynthesized wiki \(wikiId): completed")
        } catch {
            NSLog("[Campsis] Resynthesis failed for wiki \(wikiId): \(error)")
            // 기존 내용이 있으면 유지(completed), 첫 종합 실패면 failed.
            wiki.markdownStatus = hadContent ? .completed : .failed
            try? wikiRepository.save(&wiki)
        }
        await MainActor.run { NotificationCenter.default.post(name: .wikiUpdated, object: nil) }
    }

    // MARK: - 재료 구성

    private func buildNoteInputs(_ sourceIds: [String]) -> [WikiNoteInput] {
        var notes: [WikiNoteInput] = []
        for sid in sourceIds {
            guard let s = try? sourceRepository.fetch(id: sid) else { continue }
            let body = sourceRepository.readMarkdown(s)
                ?? s.content ?? s.ocrText ?? s.transcript ?? s.summary ?? ""
            notes.append(WikiNoteInput(
                title: s.displayTitle,
                summary: s.summary,
                body: String(body.prefix(maxNoteBodyChars)),
                capturedAt: s.capturedAt))
        }
        return notes
    }

    // MARK: - 재임베딩 (OW2: 위키 페이지 임베딩)

    private func embedWiki(_ wiki: Wiki, summary: String?, markdown: String) async {
        do {
            try await embeddingService.loadIfNeeded()
        } catch {
            NSLog("[Campsis] Embedding model unavailable for wiki \(wiki.id)")
            return
        }
        let text = [wiki.title, summary ?? "", markdown]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        guard !text.isEmpty else { return }
        do {
            let vector = try await embeddingService.embed(text)
            try wikiRepository.saveEmbedding(vector, forWiki: wiki.id,
                                             model: EmbeddingService.modelName,
                                             version: EmbeddingService.embeddingVersion)
        } catch {
            NSLog("[Campsis] Wiki embedding failed \(wiki.id): \(error)")
        }
    }

    // MARK: - 관련 위키 백링크 (related_topics → wiki_wiki_link)

    private func applyRelatedTopics(_ topics: [String], for wiki: Wiki) {
        for topic in topics {
            let slug = WikiRouter.slug(topic)
            guard slug != wiki.topicSlug,
                  let target = try? wikiRepository.fetch(topicSlug: slug),
                  target.id != wiki.id else { continue }
            try? wikiRepository.addWikiLink(from: wiki.id, to: target.id, weight: 0.8, kind: .relatedTopic)
            try? wikiRepository.addWikiLink(from: target.id, to: wiki.id, weight: 0.8, kind: .relatedTopic)
        }
    }

    // MARK: - 유사도 백링크 (piggyback)

    /// 방금 재임베딩된 위키를 기준으로 유사 위키 `similarity` 백링크를 재계산한다.
    /// 저장된 임베딩만 사용(LLM 비호출) → 추가 비용 0. slug가 달라도 의미가 가까우면 연결.
    private func linkSimilarWikis(wikiId: String) {
        let maintenance = WikiMaintenance(wikiRepository: wikiRepository)
        let targets = maintenance.similarityTargets(forWiki: wikiId)
        try? wikiRepository.replaceSimilarityLinks(forWiki: wikiId, targets: targets)
    }
}
