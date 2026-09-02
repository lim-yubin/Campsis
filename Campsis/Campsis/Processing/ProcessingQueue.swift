import Foundation

@available(macOS 26.0, *)
actor ProcessingQueue {
    private let repository: SourceRepository
    private let embeddingService: EmbeddingService
    private let embeddingRepository: EmbeddingRepository
    private let maxAttempts = 3
    private var isProcessing = false
    private var markdownGenerator: MarkdownGenerator?

    init(repository: SourceRepository,
         embeddingService: EmbeddingService, embeddingRepository: EmbeddingRepository) {
        self.repository = repository
        self.embeddingService = embeddingService
        self.embeddingRepository = embeddingRepository
    }

    /// 이해(Luna) 백엔드를 설정한다. Luna 구성 시 주입, 로컬 전용이면 nil (처리 대기 유지).
    func setMarkdownGenerator(_ generator: MarkdownGenerator?) {
        markdownGenerator = generator
    }

    func enqueue(_ source: Source) {
        Task { await runProcessing() }
    }

    func processAllPending() {
        Task { await runProcessing() }
    }

    private func runProcessing() async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        // Luna 미구성이면 대기 유지 (설정되면 재처리). 불필요한 조회를 피한다.
        guard markdownGenerator != nil else { return }

        do {
            let pending = try repository.fetchPending(limit: 10)
            for var source in pending {
                await processSource(&source)
            }
        } catch {
            NSLog("[Campsis] ProcessingQueue fetch error: \(error)")
        }
    }

    /// 캡처된 소스를 Luna 단일 호출로 이해(OCR+요약+태그+MD)하고, MD 기준으로 임베딩한다.
    private func processSource(_ source: inout Source) async {
        guard let markdownGenerator else { return }

        source.processingStatus = .processing
        source.markdownStatus = .processing
        source.processingAttempts += 1
        try? repository.updateProcessingResult(&source)

        do {
            let note = try await markdownGenerator.generate(from: source)
            // writeMarkdown이 markdown_path/status/updated_at를 갱신한다.
            source.markdownEdited = false   // Luna 자동 생성물(수동 편집 아님)
            try repository.writeMarkdown(note.markdown, for: &source)
            source.title = note.title
            source.summary = note.summary
            source.topics = encodeTopics(note.tags)
            source.processingStatus = .completed
            try? repository.updateProcessingResult(&source)

            await embedSource(source)
            NSLog("[Campsis] Processed source \(source.id): completed (Luna)")

        } catch MarkdownGeneratorError.emptyInput {
            source.processingStatus = .completed
            source.markdownStatus = .completed
            try? repository.updateProcessingResult(&source)

        } catch {
            NSLog("[Campsis] Processing error for source \(source.id): \(error)")
            handleFailure(&source)
        }
    }

    private func handleFailure(_ source: inout Source) {
        if source.processingAttempts >= maxAttempts {
            source.processingStatus = .failed
            source.markdownStatus = .failed
            NSLog("[Campsis] Source \(source.id) marked as failed after \(maxAttempts) attempts")
        } else {
            source.processingStatus = .pending
            source.markdownStatus = .pending
        }
        try? repository.updateProcessingResult(&source)
    }

    private func encodeTopics(_ topics: [String]) -> String? {
        guard !topics.isEmpty else { return nil }
        guard let data = try? JSONEncoder().encode(topics),
              let json = String(data: data, encoding: .utf8) else { return nil }
        return json
    }

    private func embedSource(_ source: Source) async {
        do {
            try await embeddingService.loadIfNeeded()
        } catch {
            NSLog("[Campsis] Embedding model not available: \(error)")
            return
        }

        // MD(진실원)가 있으면 그것으로 임베딩한다 (D39).
        let markdown = repository.readMarkdown(source)
        let searchableText = SearchableTextBuilder.build(from: source, markdown: markdown)
        guard !searchableText.isEmpty else { return }

        do {
            let vector = try await embeddingService.embed(searchableText)
            // 재임베딩 대비: 기존 벡터를 지우고 새로 저장 (source당 1개 유지).
            try? embeddingRepository.delete(forSourceId: source.id)
            var record = EmbeddingRecord(
                sourceId: source.id,
                vector: vector,
                model: EmbeddingService.modelName,
                version: EmbeddingService.embeddingVersion
            )
            try embeddingRepository.save(&record)
            NSLog("[Campsis] Embedding saved for source \(source.id)")
        } catch {
            NSLog("[Campsis] Embedding failed for source \(source.id): \(error)")
        }
    }

    /// 특정 소스를 다시 임베딩한다 (MD 수동 편집 후 호출). MD 진실원 기준으로 재계산.
    func reembedSource(id: String) async {
        guard let source = try? repository.fetch(id: id) else { return }
        await embedSource(source)
    }

    /// 원본 내용을 편집한 뒤 정리본을 재생성하고 재임베딩한다 (B3).
    /// 텍스트 계열(selectedText/note/file) 원본 편집에만 사용한다.
    func regenerate(id: String, newContent: String) async {
        guard var source = try? repository.fetch(id: id) else { return }
        source.content = newContent
        source.markdownStatus = .pending   // 정리본을 다시 만들어야 함
        try? repository.update(&source)
        // Luna 재호출로 제목/요약/태그/MD 재생성 후 MD 기준 재임베딩 (generator 없으면 no-op).
        await processSource(&source)
    }

    func embedAllMissing() async {
        do {
            try await embeddingService.loadIfNeeded()
        } catch {
            NSLog("[Campsis] Embedding model not available for batch: \(error)")
            return
        }

        do {
            let sources = try embeddingRepository.sourcesWithoutEmbedding(
                model: EmbeddingService.modelName,
                version: EmbeddingService.embeddingVersion
            )
            for source in sources {
                await embedSource(source)
            }
        } catch {
            NSLog("[Campsis] Batch embedding error: \(error)")
        }
    }
}
