import Foundation
import PDFKit
import UniformTypeIdentifiers

nonisolated enum FileImportError: Error, Sendable {
    case unsupportedType(String)
    case readFailed(String)
    case copyFailed(String)
}

nonisolated struct FileImporter: Sendable {
    private let repository: SourceRepository
    private let processingQueue: ProcessingQueue?

    init(repository: SourceRepository, processingQueue: ProcessingQueue?) {
        self.repository = repository
        self.processingQueue = processingQueue
    }

    func importFile(at url: URL) async throws -> Source {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let uttype = UTType(filenameExtension: url.pathExtension)

        if uttype?.conforms(to: .pdf) == true {
            return try await importPDF(at: url)
        } else if uttype?.conforms(to: .plainText) == true || url.pathExtension == "md" {
            return try await importText(at: url)
        } else if uttype?.conforms(to: .image) == true {
            return try await importImage(at: url)
        } else {
            throw FileImportError.unsupportedType(url.pathExtension)
        }
    }

    private func importPDF(at url: URL) async throws -> Source {
        let destPath = copyToFiles(url)

        guard let document = PDFDocument(url: url) else {
            throw FileImportError.readFailed("Cannot open PDF: \(url.lastPathComponent)")
        }

        // 텍스트 추출은 공용 추출기 사용(외부 편집 후 재처리와 동일 로직).
        let fullText = FileTextExtractor.extractText(fileURL: url)

        var source = Source(
            type: .file,
            content: fullText,
            filePath: destPath,
            application: "PDF",
            windowTitle: url.lastPathComponent
        )

        try repository.save(&source)
        if let queue = processingQueue {
            await queue.enqueue(source)
        }
        NSLog("[Campsis] Imported PDF: \(url.lastPathComponent) (\(document.pageCount) pages)")
        return source
    }

    private func importText(at url: URL) async throws -> Source {
        let destPath = copyToFiles(url)

        let content: String
        do {
            content = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw FileImportError.readFailed("Cannot read text file: \(error.localizedDescription)")
        }

        var source = Source(
            type: .file,
            content: content,
            filePath: destPath,
            application: url.pathExtension.uppercased(),
            windowTitle: url.lastPathComponent
        )

        try repository.save(&source)
        if let queue = processingQueue {
            await queue.enqueue(source)
        }
        NSLog("[Campsis] Imported text file: \(url.lastPathComponent)")
        return source
    }

    private func importImage(at url: URL) async throws -> Source {
        let destPath = copyToFiles(url)

        var source = Source(
            type: .file,
            filePath: destPath,
            application: "Image",
            windowTitle: url.lastPathComponent
        )

        try repository.save(&source)
        if let queue = processingQueue {
            await queue.enqueue(source)
        }
        NSLog("[Campsis] Imported image: \(url.lastPathComponent)")
        return source
    }

    private func copyToFiles(_ url: URL) -> String? {
        let fm = FileManager.default
        let ext = url.pathExtension
        let filename = UUID().uuidString + (ext.isEmpty ? "" : ".\(ext)")
        let dest = AppPaths.files.appending(path: filename)

        do {
            try AppPaths.ensureDirectories()
            try fm.copyItem(at: url, to: dest)
            return AppPaths.relativePath(from: dest)
        } catch {
            NSLog("[Campsis] File copy failed: \(error)")
            return nil
        }
    }
}
