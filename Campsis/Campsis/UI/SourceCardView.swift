import SwiftUI

struct SourceCardView: View {
    let result: SearchResult

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            typeIcon
                .frame(width: 32, height: 32)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(titleText)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(scoreText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let summary = result.source.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    if let app = result.source.application {
                        Label(app, systemImage: "app")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Text(dateText)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(10)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 0.5))
    }

    private var typeIcon: some View {
        Image(systemName: iconName)
            .foregroundStyle(iconColor)
    }

    private var iconName: String {
        switch result.source.type {
        case .selectedText: return "text.quote"
        case .screenshot: return "camera"
        case .note: return "note.text"
        case .voice: return "waveform"
        case .file: return "doc"
        }
    }

    private var iconColor: Color {
        switch result.source.type {
        case .selectedText: return .blue
        case .screenshot: return .purple
        case .note: return .orange
        case .voice: return .green
        case .file: return .gray
        }
    }

    private var titleText: String {
        if let title = result.source.windowTitle, !title.isEmpty {
            return title
        }
        if let content = result.source.content, !content.isEmpty {
            return String(content.prefix(60))
        }
        return result.source.type.rawValue.capitalized
    }

    private var scoreText: String {
        String(format: "%.0f%%", result.score * 100)
    }

    private var dateText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: result.source.capturedAt, relativeTo: Date())
    }
}
