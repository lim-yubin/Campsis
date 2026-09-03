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

    // B3: 원본 편집 → 정리본 재생성
    @State private var displayContent: String?
    @State private var isEditingOriginal = false
    @State private var originalDraft: String = ""
    @State private var originalSaveError: String?
    @State private var isRegenerating = false
    @State private var noteManuallyEdited: Bool
    @State private var showOverwriteConfirm = false
    @State private var pendingOriginal: String?

    // Phase 5: 복사 토스트
    @State private var toastMessage: String?

    /// 섹션 우상단 복사 버튼. 복사 후 공용 토스트를 띄운다.
    private func copyIconButton(_ text: String) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            toastMessage = "복사되었습니다"
        } label: {
            Image(systemName: "doc.on.doc")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .help("복사")
    }

    /// 원본 텍스트를 편집할 수 있는 유형(이미지/음성 제외).
    private var canEditOriginal: Bool {
        switch source.type {
        case .selectedText, .note, .file: return true
        case .screenshot, .voice: return false
        }
    }

    init(source: Source, initialTab: SourceDetailTab? = nil) {
        self.source = source
        let defaultTab: SourceDetailTab = source.markdownPath != nil ? .markdown : .original
        _selectedTab = State(initialValue: initialTab ?? defaultTab)
        _markdownUpdatedAt = State(initialValue: source.markdownUpdatedAt)
        _displayContent = State(initialValue: source.content)
        _noteManuallyEdited = State(initialValue: source.markdownEdited)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                tabHeader

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
        .copyToast($toastMessage)
        .navigationTitle(source.displayTitle)
        .task { loadMarkdown() }
        .toolbar { toolbarContent }
        .alert("정리본을 다시 만들까요?", isPresented: $showOverwriteConfirm) {
            Button("취소", role: .cancel) { pendingOriginal = nil }
            Button("재생성", role: .destructive) {
                if let pending = pendingOriginal { performRegenerate(pending) }
                pendingOriginal = nil
            }
        } message: {
            Text("직접 수정한 정리본이 있습니다. 원본을 저장하면 AI가 정리본을 새로 만들어 기존 수정 내용을 덮어씁니다.")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if selectedTab == .markdown && !isRegenerating {
            if isEditing {
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { saveMarkdown() }
                        .keyboardShortcut("s", modifiers: .command)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { isEditing = false }
                }
            } else {
                if let md = markdownText, !md.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("마크다운으로 복사") {
                                MarkdownClipboard.copyMarkdown(md)
                                toastMessage = "복사되었습니다"
                            }
                            Button("일반 텍스트로 복사") {
                                MarkdownClipboard.copyPlain(md)
                                toastMessage = "복사되었습니다"
                            }
                        } label: {
                            Label("복사", systemImage: "doc.on.doc")
                        }
                        .help("정리본 복사")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        startEditing()
                    } label: {
                        Label(markdownText?.isEmpty == false ? "정리본 다듬기" : "직접 작성",
                              systemImage: "square.and.pencil")
                    }
                    .help("정리본의 표현을 직접 다듬어요. 내용 변경은 원본 수정으로 하세요.")
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

    /// 정리본을 주 화면으로 두고, 원본은 보조 토글로 접근하도록 하는 헤더.
    @ViewBuilder
    private var tabHeader: some View {
        if selectedTab == .markdown {
            HStack(spacing: 10) {
                Label("정리본", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation { selectedTab = .original }
                } label: {
                    Label(originalButtonLabel, systemImage: "doc.plaintext")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isEditing || isEditingOriginal || isRegenerating)
            }
        } else {
            HStack(spacing: 10) {
                Button {
                    withAnimation { selectedTab = .markdown }
                } label: {
                    Label("정리본으로", systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isEditingOriginal || isRegenerating)

                Label("원본", systemImage: "doc.plaintext")
                    .font(.headline)
                Spacer()
            }
        }
    }

    /// "원본 보기 (N자)" — 텍스트 계열이면 글자 수 표시.
    private var originalButtonLabel: String {
        if let count = (displayContent ?? source.content)?.count, count > 0 {
            return "원본 보기 (\(count)자)"
        }
        return "원본 보기"
    }

    @ViewBuilder
    private var markdownTab: some View {
        if isRegenerating {
            VStack(spacing: 12) {
                ProgressView()
                Text("수정한 원본으로 정리본을 다시 만드는 중이에요…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        } else if isEditing {
            markdownEditor
        } else if let md = markdownText, !md.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                MarkdownTextView(text: md)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("AI가 원본을 정리한 노트예요. 내용을 바꾸려면 원본을 수정하세요.")
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
            Label("고급: 표현만 다듬기 — 내용을 바꾸려면 원본을 수정하세요.", systemImage: "wand.and.stars")
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
        updated.markdownEdited = true   // 사용자가 직접 수정한 정리본
        do {
            try appState.sourceRepository.writeMarkdown(trimmed, for: &updated)
            markdownText = trimmed
            markdownUpdatedAt = updated.markdownUpdatedAt
            noteManuallyEdited = true
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

    // MARK: - 원본 편집 (B3)

    @ViewBuilder
    private var originalEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextEditor(text: $originalDraft)
                .font(.body)
                .frame(minHeight: 240)
                .padding(8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

            if let originalSaveError {
                Label(originalSaveError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Label("저장하면 AI가 정리본을 다시 만들고 검색에도 반영해요.", systemImage: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("취소") { isEditingOriginal = false }
                Button("저장") { saveOriginal() }
                    .keyboardShortcut("s", modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .disabled(originalDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func startEditingOriginal() {
        originalDraft = displayContent ?? source.content ?? ""
        originalSaveError = nil
        selectedTab = .original
        isEditingOriginal = true
    }

    private func saveOriginal() {
        let trimmed = originalDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // 직접 수정한 정리본이 재생성으로 덮어써지는 경우 경고
        if noteManuallyEdited, let md = markdownText, !md.isEmpty {
            pendingOriginal = trimmed
            showOverwriteConfirm = true
        } else {
            performRegenerate(trimmed)
        }
    }

    private func performRegenerate(_ newContent: String) {
        guard let queue = appState.processingQueueRef as? ProcessingQueue else {
            originalSaveError = "처리 엔진을 사용할 수 없어요."
            return
        }
        displayContent = newContent
        isEditingOriginal = false
        isRegenerating = true
        markdownText = nil
        originalSaveError = nil
        selectedTab = .markdown   // 재생성 진행을 정리본 탭에서 보여준다

        let id = source.id
        Task {
            await queue.regenerate(id: id, newContent: newContent)
            await MainActor.run { reloadAfterRegenerate(id: id) }
        }
    }

    private func reloadAfterRegenerate(id: String) {
        if let fresh = try? appState.sourceRepository.fetch(id: id) {
            markdownText = appState.sourceRepository.readMarkdown(fresh)
            markdownUpdatedAt = fresh.markdownUpdatedAt
            displayContent = fresh.content
            noteManuallyEdited = fresh.markdownEdited   // 재생성 후 자동본이므로 false
        }
        isRegenerating = false
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

                Text(source.displayTitle)
                    .font(.title2.bold())
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
            let content = displayContent ?? source.content
            if isEditingOriginal {
                GroupBox("원본 편집") { originalEditor }
            } else if let content, !content.isEmpty {
                GroupBox {
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

                            Spacer()

                            if canEditOriginal {
                                Button {
                                    startEditingOriginal()
                                } label: {
                                    Label("원본 수정 → 정리본 재생성", systemImage: "arrow.triangle.2.circlepath")
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .help("원본을 수정하면 AI가 정리본을 새로 만들어요. (주 편집 경로)")
                            }

                            if source.type == .file, let path = source.filePath {
                                Button("원본 열기") {
                                    let url = AppPaths.absoluteURL(from: path)
                                    NSWorkspace.shared.open(url)
                                }
                                .font(.caption)
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text("내용")
                        Spacer()
                        copyIconButton(content)
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
                            .scaledToFit()
                            .frame(maxWidth: .infinity)          // 가용 폭을 채움 → 크게 표시
                            .contentShape(Rectangle())
                            .onTapGesture { NSWorkspace.shared.open(url) }  // 클릭 시 원본 크기로 열기
                            .help("클릭하면 원본 크기로 열려요")
                    }
                }
            }
            if let ocrText = source.ocrText, !ocrText.isEmpty {
                GroupBox {
                    Text(ocrText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    HStack {
                        Text("OCR 텍스트")
                        Spacer()
                        copyIconButton(ocrText)
                    }
                }
            }
        case .voice:
            if let transcript = source.transcript, !transcript.isEmpty {
                GroupBox {
                    Text(transcript)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    HStack {
                        Text("전사")
                        Spacer()
                        copyIconButton(transcript)
                    }
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
        GroupBox {
            Text(summary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            HStack {
                Text("AI 요약")
                Spacer()
                copyIconButton(summary)
            }
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
