import Foundation
import PDFKit
import UniformTypeIdentifiers

/// 문서형 파일(PDF/plain text/md)에서 텍스트를 추출한다.
/// 파일 import 시점과 외부 편집 후 재처리 시점에서 공용으로 사용한다.
nonisolated enum FileTextExtractor {
    /// 지원 문서형 파일에서 텍스트를 추출한다. 이미지/기타 형식은 nil.
    static func extractText(fileURL url: URL) -> String? {
        let ext = url.pathExtension.lowercased()
        let uttype = UTType(filenameExtension: ext)

        if uttype?.conforms(to: .pdf) == true {
            guard let document = PDFDocument(url: url) else { return nil }
            var fullText = ""
            for i in 0..<document.pageCount {
                if let page = document.page(at: i), let text = page.string {
                    if !fullText.isEmpty { fullText += "\n\n" }
                    fullText += text
                }
            }
            return fullText.isEmpty ? nil : fullText
        }

        if uttype?.conforms(to: .plainText) == true || ext == "md" {
            return try? String(contentsOf: url, encoding: .utf8)
        }

        return nil
    }

    /// 이미지 형식 파일인지 여부 (외부 편집 후 재처리 분기용).
    static func isImage(fileURL url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension.lowercased())?.conforms(to: .image) == true
    }
}
