import Foundation

@available(macOS 26.0, *)
actor ProcessingQueue {
    private let repository: SourceRepository
    private let generator: TextGenerator
    private let embeddingService: EmbeddingService
    private let embeddingRepository: EmbeddingRepository
    private let maxAttempts = 3
    private var isProcessing = false
    private var markdownGenerator: MarkdownGenerator?
    private var isGeneratingMarkdown = false

    init(repository: SourceRepository, generator: TextGenerator,
         embeddingService: EmbeddingService, embeddingRepository: EmbeddingRepository) {
        self.repository = repository
        self.generator = generator
        self.embeddingService = embeddingService
        self.embeddingRepository = embeddingRepository
    }

    /// MD 생성 백엔드를 설정한다. Luna 구성 시 주입, 로컬 전용이면 nil (MD 생성 건너뜀).
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

        do {
            let pending = try repository.fetchPending(limit: 10)
            for var source in pending {
                await processSource(&source)
            }
        } catch {
            NSLog("[Campsis] ProcessingQueue fetch error: \(error)")
        }

        // 처리 완료 후, 온라인 + Luna 구성 시 MD를 백그라운드로 보강한다 (D40).
        await generateMissingMarkdown()
    }

    private func processSource(_ source: inout Source) async {
        source.processingStatus = .processing
        source.processingAttempts += 1
        try? repository.updateProcessingResult(&source)

        do {
            if source.screenshotPath != nil && source.ocrText == nil {
                let ocrText = try await OCRProcessor.recognizeText(from: source)
                source.ocrText = ocrText
            }

            let textToAnalyze = buildAnalysisInput(from: source)

            if !textToAnalyze.isEmpty {
                let analysis = try await generator.analyze(textToAnalyze)
                source.summary = analysis.summary
                source.topics = encodeTopics(analysis.topics)
            }

            source.processingStatus = .completed
            try? repository.updateProcessingResult(&source)

            await embedSource(source)
            NSLog("[Campsis] Processed source \(source.id): completed")

        } catch TextGeneratorError.guardrailRefusal {
            NSLog("[Campsis] Guardrail refusal for source \(source.id) (attempt \(source.processingAttempts)/\(maxAttempts))")
            handleFailure(&source)

        } catch TextGeneratorError.emptyInput {
            source.processingStatus = .completed
            try? repository.updateProcessingResult(&source)

        } catch {
            NSLog("[Campsis] Processing error for source \(source.id): \(error)")
            handleFailure(&source)
        }
    }

    private func handleFailure(_ source: inout Source) {
        if source.processingAttempts >= maxAttempts {
            source.processingStatus = .failed
            NSLog("[Campsis] Source \(source.id) marked as failed after \(maxAttempts) attempts")
        } else {
            source.processingStatus = .pending
        }
        try? repository.updateProcessingResult(&source)
    }

    private func buildAnalysisInput(from source: Source) -> String {
        var parts: [String] = []

        if let content = source.content, !content.isEmpty {
            parts.append(content)
        }
        if let ocrText = source.ocrText, !ocrText.isEmpty {
            parts.append(ocrText)
        }
        if let userNote = source.userNote, !userNote.isEmpty {
            parts.append("User note: \(userNote)")
        }

        return parts.joined(separator: "\n\n")
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

        let searchableText = SearchableTextBuilder.build(from: source)
        guard !searchableText.isEmpty else { return }

        do {
            let vector = try await embeddingService.embed(searchableText)
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

    // MARK: - Markdown 생성 (진실원, 백그라운드)

    /// MD가 없는 완료 소스들에 대해 Luna로 MD를 생성한다. Luna 미구성 시 조용히 건너뛴다.
    func generateMissingMarkdown() async {
        guard let markdownGenerator else { return }
        guard !isGeneratingMarkdown else { return }
        isGeneratingMarkdown = true
        defer { isGeneratingMarkdown = false }

        do {
            let sources = try repository.fetchMarkdownPending(limit: 20)
            for var source in sources {
                await generateMarkdown(for: &source, using: markdownGenerator)
            }
        } catch {
            NSLog("[Campsis] Markdown pending fetch error: \(error)")
        }
    }

    private func generateMarkdown(for source: inout Source, using generator: MarkdownGenerator) async {
        source.markdownStatus = .processing
        try? repository.update(&source)

        do {
            let markdown = try await generator.generate(from: source)
            try repository.writeMarkdown(markdown, for: &source)
            NSLog("[Campsis] Markdown generated for source \(source.id)")
        } catch MarkdownGeneratorError.emptyInput {
            // 정리할 내용이 없으면 실패가 아니라 완료로 둔다 (재시도 방지).
            source.markdownStatus = .completed
            try? repository.update(&source)
        } catch {
            NSLog("[Campsis] Markdown generation failed for source \(source.id): \(error)")
            source.markdownStatus = .failed
            try? repository.update(&source)
        }
    }
}
