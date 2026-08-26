import Foundation

nonisolated enum SearchableTextBuilder {
    /// D26: [User Note] + [Summary] + [Content/OCR/Transcript] + [Context]
    static func build(from source: Source) -> String {
        var sections: [String] = []

        if let note = source.userNote, !note.isEmpty {
            sections.append("[User Note]\n\(note)")
        }

        if let summary = source.summary, !summary.isEmpty {
            sections.append("[Summary]\n\(summary)")
        }

        let content = primaryContent(from: source)
        if !content.isEmpty {
            sections.append("[Content]\n\(content)")
        }

        let context = contextSection(from: source)
        if !context.isEmpty {
            sections.append("[Context]\n\(context)")
        }

        return sections.joined(separator: "\n\n")
    }

    private static func primaryContent(from source: Source) -> String {
        switch source.type {
        case .selectedText, .note, .file:
            return source.content ?? ""
        case .screenshot:
            return source.ocrText ?? ""
        case .voice:
            return source.transcript ?? ""
        }
    }

    private static func contextSection(from source: Source) -> String {
        var parts: [String] = []
        if let app = source.application, !app.isEmpty {
            parts.append(app)
        }
        if let title = source.windowTitle, !title.isEmpty {
            parts.append(title)
        }
        if let url = source.url, !url.isEmpty {
            parts.append(url)
        }
        return parts.joined(separator: "\n")
    }
}
