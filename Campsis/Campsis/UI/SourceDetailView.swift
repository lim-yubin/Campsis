import SwiftUI

enum SourceDetailTab: Hashable {
    case markdown
    case original
}

struct SourceDetailView: View {
    let source: Source
    @Environment(AppState.self) private var appState
    @State private var selectedTab: SourceDetailTab
    @State private var markdownText: String?
    @State private var markdownUpdatedAt: Date?
    @State private var isEditing = false
    @State private var draft: String = ""
    @State private var saveError: String?

    init(source: Source) {
        self.source = source
        _selectedTab = State(initialValue: source.markdownPath != nil ? .markdown : .original)
        _markdownUpdatedAt = State(initialValue: source.markdownUpdatedAt)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                Picker("보기", selection: $selectedTab) {
                    Text("정리본").tag(SourceDetailTab.markdown)
                    Text("원본").tag(SourceDetailTab.original)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(isEditing)

                Divider()

                switch selectedTab {
                case .markdown:
                    markdownTab
                case .original:
                    originalTab
                }
            }
            .padding(24)
        }
        .frame(minWidth: 500, minHeight: 400)
        .navigationTitle(source.windowTitle ?? "메모리")
        .task { loadMarkdown() }
        .toolbar { toolbarContent }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if selectedTab == .markdown {
            if isEditing {
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { saveMarkdown() }
                        .keyboardShortcut("s", modifiers: .command)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { isEditing = false }
                }
            } else {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        startEditing()
                    } label: {
                        Label(markdownText?.isEmpty == false ? "편집" : "직접 작성",
                              systemImage: "square.and.pencil")
                    }
                }
            }
        }
        if !isEditing, let url = openableURL {
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("원문 열기", systemImage: "arrow.up.right.square")
                }
            }
        }
    }

    // MARK: - Tabs

    @ViewBuilder
    private var markdownTab: some View {
        if isEditing {
            markdownEditor
        } else if let md = markdownText, !md.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                MarkdownTextView(text: md)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("AI가 정리한 노트예요. 원본은 '원본' 탭에서 확인하세요.")
                    if let updated = markdownUpdatedAt {
                        Text("· \(updated, style: .date)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
        } else {
            markdownPlaceholder
        }
    }

    @ViewBuilder
    private var markdownEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("마크다운으로 편집")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $draft)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 320)
                .padding(8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

            if let saveError {
                Label(saveError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Text("⌘S 로 저장할 수 있어요.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var markdownPlaceholder: some View {
        VStack(spacing: 12) {
            switch source.markdownStatus {
            case .processing:
                ProgressView()
                Text("정리본을 만드는 중이에요…")
            case .pending:
                Image(systemName: "clock")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
                Text("정리본 생성 대기 중\n(온라인 상태에서 AI가 자동으로 정리합니다)")
                    .multilineTextAlignment(.center)
            case .failed:
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)
                Text("정리본 생성에 실패했어요. 잠시 후 다시 시도됩니다.")
            case .completed:
                Text("정리본이 아직 없어요.")
            }

            Button {
                startEditing()
            } label: {
                Label("직접 작성", systemImage: "square.and.pencil")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func startEditing() {
        draft = markdownText ?? ""
        saveError = nil
        selectedTab = .markdown
        isEditing = true
    }

    private func saveMarkdown() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        var updated = source
        do {
            try appState.sourceRepository.writeMarkdown(trimmed, for: &updated)
            markdownText = trimmed
            markdownUpdatedAt = updated.markdownUpdatedAt
            isEditing = false
            saveError = nil
            // 편집한 정리본이 검색에도 반영되도록 해당 항목만 재임베딩한다 (7.8).
            if let queue = appState.processingQueueRef as? ProcessingQueue {
                let id = source.id
                Task { await queue.reembedSource(id: id) }
            }
        } catch {
            saveError = error.localizedDescription
            NSLog("[Campsis] Markdown save failed for \(source.id): \(error)")
        }
    }

    @ViewBuilder
    private var originalTab: some View {
        contentSection
        if let summary = source.summary, !summary.isEmpty {
            summarySection(summary)
        }
        if let topics = decodedTopics, !topics.isEmpty {
            topicsSection(topics)
        }
        metadataSection
    }

    private func loadMarkdown() {
        guard let path = source.markdownPath else { return }
        markdownText = try? String(contentsOf: AppPaths.absoluteURL(from: path), encoding: .utf8)
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
