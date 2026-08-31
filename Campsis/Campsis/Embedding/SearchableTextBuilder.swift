import Foundation

nonisolated enum SearchableTextBuilder {
    /// D26/D39: [User Note] + [Note(MD 진실원) | Summary+Content] + [Context]
    ///
    /// MD(정리본)가 있으면 그것을 진실원으로 삼아 요약·본문 대신 사용한다.
    /// 없으면 기존처럼 요약 + 원본 콘텐츠로 구성한다.
    static func build(from source: Source, markdown: String? = nil) -> String {
        var sections: [String] = []

        if let note = source.userNote, !note.isEmpty {
            sections.append("[User Note]\n\(note)")
        }

        if let md = markdown?.trimmingCharacters(in: .whitespacesAndNewlines), !md.isEmpty {
            sections.append("[Note]\n\(md)")
        } else {
            if let summary = source.summary, !summary.isEmpty {
                sections.append("[Summary]\n\(summary)")
            }
            let content = primaryContent(from: source)
            if !content.isEmpty {
                sections.append("[Content]\n\(content)")
            }
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
