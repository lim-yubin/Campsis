import SwiftUI

struct SourceDetailView: View {
    let source: Source
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                Divider()
                contentSection
                if let summary = source.summary, !summary.isEmpty {
                    summarySection(summary)
                }
                if let topics = decodedTopics, !topics.isEmpty {
                    topicsSection(topics)
                }
                metadataSection
            }
            .padding(24)
        }
        .frame(minWidth: 500, minHeight: 400)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("닫기") { dismiss() }
            }
            if let url = openableURL {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Label("원문 열기", systemImage: "arrow.up.right.square")
                    }
                }
            }
        }
    }

    private var openableURL: URL? {
        if let urlString = source.url, let url = URL(string: urlString) {
            return url
        }
        if source.type == .file, let path = source.filePath {
            return AppPaths.absoluteURL(from: path)
        }
        return nil
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(source.type.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())

                if let title = source.windowTitle {
                    Text(title)
                        .font(.title2.bold())
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(source.capturedAt, style: .date)
                Text(source.capturedAt, style: .time)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
        }
    }

    private static let contentPreviewLimit = 2000

    @State private var showFullContent = false

    @ViewBuilder
    private var contentSection: some View {
        switch source.type {
        case .selectedText, .note, .file:
            if let content = source.content {
                GroupBox("내용") {
                    VStack(alignment: .leading, spacing: 8) {
                        if showFullContent {
                            ScrollView {
                                Text(content)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 400)
                        } else {
                            let preview = content.count > Self.contentPreviewLimit
                                ? String(content.prefix(Self.contentPreviewLimit)) + "..."
                                : content
                            Text(preview)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        HStack {
                            if content.count > Self.contentPreviewLimit {
                                Button(showFullContent ? "간략히 보기" : "전체 보기 (\(content.count)자)") {
                                    showFullContent.toggle()
                                }
                                .font(.caption)
                                .buttonStyle(.borderless)
                            }

                            if source.type == .file, let path = source.filePath {
                                Spacer()
                                Button("원본 열기") {
                                    let url = AppPaths.absoluteURL(from: path)
                                    NSWorkspace.shared.open(url)
                                }
                                .font(.caption)
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
            }
        case .screenshot:
            if let path = source.screenshotPath {
                let url = AppPaths.absoluteURL(from: path)
                if let nsImage = NSImage(contentsOf: url) {
                    GroupBox("스크린샷") {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 300)
                    }
                }
            }
            if let ocrText = source.ocrText, !ocrText.isEmpty {
                GroupBox("OCR 텍스트") {
                    Text(ocrText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        case .voice:
            if let transcript = source.transcript {
                GroupBox("전사") {
                    Text(transcript)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }

        if let note = source.userNote, !note.isEmpty {
            GroupBox("메모") {
                Text(note)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func summarySection(_ summary: String) -> some View {
        GroupBox("AI 요약") {
            Text(summary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func topicsSection(_ topics: [String]) -> some View {
        GroupBox("주제") {
            FlowLayout(spacing: 6) {
                ForEach(topics, id: \.self) { topic in
                    Text(topic)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.tagBackground, in: Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var metadataSection: some View {
        GroupBox("메타데이터") {
            Grid(alignment: .leading, verticalSpacing: 6) {
                if let app = source.application {
                    GridRow {
                        Text("앱").foregroundStyle(.secondary)
                        Text(app)
                    }
                }
                if let url = source.url {
                    GridRow {
                        Text("URL").foregroundStyle(.secondary)
                        Link(url, destination: URL(string: url) ?? URL(string: "about:blank")!)
                            .lineLimit(1)
                    }
                }
                GridRow {
                    Text("상태").foregroundStyle(.secondary)
                    Text(source.processingStatus.rawValue)
                }
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var decodedTopics: [String]? {
        guard let json = source.topics,
              let data = json.data(using: .utf8),
              let topics = try? JSONDecoder().decode([String].self, from: data) else { return nil }
        return topics
    }
}

struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let point = CGPoint(x: bounds.minX + result.positions[index].x,
                              y: bounds.minY + result.positions[index].y)
            subview.place(at: point, proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
