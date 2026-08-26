import Foundation
import Vision

nonisolated enum OCRProcessor {
    static func recognizeText(from imageURL: URL) async throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ko-KR", "en-US"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(url: imageURL, options: [:])
        try handler.perform([request])

        guard let observations = request.results else {
            return ""
        }

        let text = observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")

        return text
    }

    static func recognizeText(from source: Source) async throws -> String? {
        guard let screenshotPath = source.screenshotPath else { return nil }
        let url = AppPaths.absoluteURL(from: screenshotPath)
        let text = try await recognizeText(from: url)
        return text.isEmpty ? nil : text
    }
}
