import Foundation

@available(macOS 26.0, *)
actor ProcessingQueue {
    private let repository: SourceRepository
    private let generator: TextGenerator
    private let maxAttempts = 3
    private var isProcessing = false

    init(repository: SourceRepository, generator: TextGenerator) {
        self.repository = repository
        self.generator = generator
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
}
