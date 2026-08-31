import Foundation
import Vision

/// 이미지에서 텍스트를 추출하는 백엔드 추상화 (7.7, D41).
/// 로컬(AppleVisionOCR) 기본, 추후 Windows 등 플랫폼 확장 시 다른 구현으로 교체 가능.
/// 이미지 "이해/해석"은 별도로 Luna 비전(MarkdownGenerator)이 담당한다.
protocol OCRProcessing: Sendable {
    func recognizeText(from imageURL: URL) async throws -> String
}

/// macOS Vision 프레임워크 기반 로컬 OCR.
nonisolated struct AppleVisionOCR: OCRProcessing {
    func recognizeText(from imageURL: URL) async throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ko-KR", "en-US"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(url: imageURL, options: [:])
        try handler.perform([request])

        guard let observations = request.results else {
            return ""
        }

        return observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }
}

nonisolated enum OCRProcessor {
    /// 기본 OCR 백엔드. 필요 시 다른 `OCRProcessing` 구현으로 교체.
    static let defaultRecognizer: OCRProcessing = AppleVisionOCR()

    static func recognizeText(from imageURL: URL) async throws -> String {
        try await defaultRecognizer.recognizeText(from: imageURL)
    }

    static func recognizeText(from source: Source) async throws -> String? {
        guard let screenshotPath = source.screenshotPath else { return nil }
        let url = AppPaths.absoluteURL(from: screenshotPath)
        let text = try await recognizeText(from: url)
        return text.isEmpty ? nil : text
    }
}
