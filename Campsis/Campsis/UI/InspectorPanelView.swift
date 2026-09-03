import SwiftUI

/// 오른쪽 분할 패널. 채팅 답변의 출처 정리본을 미리 보거나, 전체 메모리 목록을
/// 컴팩트하게 탐색해 메모리와 채팅을 나란히 볼 수 있게 한다. (읽기 전용 미리보기)
/// 인스펙터 미리보기에서 "전체 보기"로 열 상세 요청.
private struct FullDetailRequest: Identifiable {
    let source: Source
    let tab: SourceDetailTab?
    var id: String { source.id + (tab.map { "\($0)" } ?? "") }
}

struct InspectorPanelView: View {
    @Environment(AppState.self) private var appState
    @State private var fullDetail: FullDetailRequest?

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            if appState.inspectorMode == .wiki, let wiki = appState.inspectorWiki {
                // 위키 미리보기: 채팅 대화를 떠나지 않고 옆에서 위키를 확인.
                wikiPreviewHeader
                Divider()
                WikiPreviewView(wiki: wiki)
            } else {
                Picker("보기", selection: $appState.inspectorMode) {
                    Text("정리본").tag(InspectorMode.source)
                    Text("기억").tag(InspectorMode.memories)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()

                switch appState.inspectorMode {
                case .source:
                    if let source = appState.inspectorSource {
                        SourcePreviewView(source: source) { tab in
                            fullDetail = FullDetailRequest(source: source, tab: tab)
                        }
                    } else {
                        ContentUnavailableView(
                            "출처를 선택하세요",
                            systemImage: "doc.text.magnifyingglass",
                            description: Text("채팅 답변 하단의 출처를 클릭하면\n정리본이 여기에 표시됩니다.")
                        )
                    }
                case .memories:
                    InspectorMemoriesList { source in
                        fullDetail = FullDetailRequest(source: source, tab: nil)
                    }
                case .wiki:
                    EmptyView()   // inspectorWiki가 없을 때만 도달(위 분기에서 처리)
                }
            }
        }
        // 폭은 인스펙터 컬럼(.inspectorColumnWidth) 한 곳에서만 관리한다.
        // 여기서 minWidth/idealWidth를 또 지정하면 리사이즈 시 두 제약이 충돌해 튕김이 발생.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 미리보기 → 편집 가능한 전체 상세로 승격.
        .sheet(item: $fullDetail) { req in
            NavigationStack {
                SourceDetailView(source: req.source, initialTab: req.tab)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("닫기") { fullDetail = nil }
                        }
                    }
            }
            .frame(minWidth: 640, minHeight: 560)
        }
    }

    /// 위키 미리보기 상단 바. 세그먼트 대신 뒤로가기 + 위키 라벨을 보여준다.
    private var wikiPreviewHeader: some View {
        HStack(spacing: 6) {
            Button {
                appState.inspectorMode = .memories
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            .help("기억 목록으로")

            Label("위키", systemImage: "books.vertical")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

/// 어느 화면에서든 분할 창(인스펙터)을 열고 닫는 툴바 토글 버튼. (A3)
struct InspectorToggleButton: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Button {
            // 열 때 아직 볼 출처가 없으면 메모리 목록을 기본으로 보여준다.
            if !appState.showInspector && appState.inspectorSource == nil {
                appState.inspectorMode = .memories
            }
            withAnimation(.easeInOut(duration: 0.2)) {
                appState.showInspector.toggle()
            }
        } label: {
            Label("분할 보기", systemImage: "sidebar.right")
        }
        .help("기억을 화면 분할로 함께 보기")
    }
}

/// 인스펙터에서 보여주는 읽기 전용 정리본. 정리본(MD)이 없으면 원본 콘텐츠로 폴백한다.
struct SourcePreviewView: View {
    let source: Source
    /// "전체 보기"/"원본" 등에서 편집 가능한 상세 화면을 열 때 호출. 탭 지정 가능.
    var onOpenFull: ((SourceDetailTab?) -> Void)? = nil
    @Environment(AppState.self) private var appState
    @State private var markdown: String?
    @State private var loaded = false
    @State private var toastMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // A1: 이미지/스크린샷 소스는 캡처본을 상단에 노출
                if let image = previewImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)   // 인스펙터 폭에 맞춰 온전히 표시
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                header

                if let md = markdown, !md.isEmpty {
                    MarkdownTextView(text: md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if let content = source.content, !content.isEmpty {
                    Text(content)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if loaded && previewImage == nil {
                    Text("표시할 내용이 없어요.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
        .copyToast($toastMessage)
        .task(id: source.id) { load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(source.displayTitle)
                        .font(.headline)
                        .lineLimit(2)
                    Text(source.capturedAt.formatted(.dateTime.year().month().day().hour().minute()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                copyMenu
            }
            if onOpenFull != nil {
                actionBar
            }
        }
    }

    /// 미리보기 → 편집 가능한 상세로 이어지는 승격 액션 모음.
    private var actionBar: some View {
        HStack(spacing: 8) {
            Button {
                onOpenFull?(nil)
            } label: {
                Label("전체 보기", systemImage: "arrow.up.forward.square")
            }

            if canShowOriginal {
                Button {
                    onOpenFull?(.original)
                } label: {
                    Label("원본", systemImage: "doc.plaintext")
                }
            }

            if let url = openableURL {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("원문 열기", systemImage: "arrow.up.right.square")
                }
            }

            Spacer(minLength: 0)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .font(.caption)
    }

    private var canShowOriginal: Bool {
        source.content?.isEmpty == false
            || source.ocrText?.isEmpty == false
            || source.transcript?.isEmpty == false
    }

    private var openableURL: URL? {
        if let urlString = source.url, let url = URL(string: urlString) { return url }
        if source.type == .file, let path = source.filePath {
            return AppPaths.absoluteURL(from: path)
        }
        return nil
    }

    // B2: 정리본 복사 — 마크다운 원문 / 일반 텍스트
    @ViewBuilder
    private var copyMenu: some View {
        if let md = markdown, !md.isEmpty {
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
                Image(systemName: "doc.on.doc")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("정리본 복사")
        }
    }

    /// 스크린샷 또는 이미지 파일이면 상단 미리보기용 이미지를 로드한다.
    private var previewImage: NSImage? {
        if source.type == .screenshot, let path = source.screenshotPath {
            return NSImage(contentsOf: AppPaths.absoluteURL(from: path))
        }
        if source.type == .file, let path = source.filePath {
            let ext = (path as NSString).pathExtension.lowercased()
            if ["png", "jpg", "jpeg", "gif", "heic", "webp", "tiff"].contains(ext) {
                return NSImage(contentsOf: AppPaths.absoluteURL(from: path))
            }
        }
        return nil
    }

    private func load() {
        markdown = appState.sourceRepository.readMarkdown(source)
        loaded = true
    }
}

/// 인스펙터용 컴팩트 메모리 목록. 항목 선택 시 정리본 미리보기로 전환한다.
private struct InspectorMemoriesList: View {
    var onOpenFull: ((Source) -> Void)? = nil
    @Environment(AppState.self) private var appState
    @State private var sources: [Source] = []

    var body: some View {
        List {
            // A4: 메모리 메뉴와 동일한 MemoryRowView를 재사용해 콘텐츠를 크고 명확하게 표시
            ForEach(sources) { source in
                MemoryRowView(source: source, isSelected: appState.inspectorSource?.id == source.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.inspectorSource = source
                        appState.inspectorMode = .source
                    }
                    .contextMenu {
                        Button("전체 보기") { onOpenFull?(source) }
                    }
                    .listRowInsets(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
            }
        }
        .listStyle(.inset)
        .overlay {
            if sources.isEmpty {
                ContentUnavailableView(
                    "기억 없음",
                    systemImage: "tray",
                    description: Text("아직 저장된 기억이 없습니다.")
                )
            }
        }
        .task { load() }
    }

    private func load() {
        sources = (try? appState.sourceRepository.fetchAll()) ?? []
    }
}

/// 인스펙터에서 보여주는 읽기 전용 위키 미리보기. 채팅 위키 출처를 클릭하면
/// 대화를 떠나지 않고 이 패널에서 종합 문서를 확인한다. 전체 화면은 "나의 위키에서 열기".
struct WikiPreviewView: View {
    let wiki: Wiki
    @Environment(AppState.self) private var appState
    @State private var current: Wiki
    @State private var markdown: String?
    @State private var toast: String?

    init(wiki: Wiki) {
        self.wiki = wiki
        _current = State(initialValue: wiki)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header

                if let md = markdown, !md.isEmpty {
                    MarkdownTextView(text: stripH1(md))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if current.markdownStatus == .pending || current.markdownStatus == .processing {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("종합 문서를 작성하고 있어요.").foregroundStyle(.secondary)
                    }
                } else {
                    Text("아직 종합 내용이 없어요.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                openFullButton
            }
            .padding(16)
        }
        .copyToast($toast)
        .task(id: wiki.id) { load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "book.closed.fill")
                    .foregroundStyle(Color.chatAccent)
                Text(current.title)
                    .font(.headline)
                    .lineLimit(2)
                Spacer(minLength: 8)
                copyMenu
            }
            if let summary = current.summary, !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text("메모 \(current.memberCount)개로 만들어졌어요")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var copyMenu: some View {
        if let md = markdown, !md.isEmpty {
            Menu {
                Button("마크다운으로 복사") {
                    MarkdownClipboard.copyMarkdown(md)
                    toast = "복사되었습니다"
                }
                Button("일반 텍스트로 복사") {
                    MarkdownClipboard.copyPlain(md)
                    toast = "복사되었습니다"
                }
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("위키 복사")
        }
    }

    private var openFullButton: some View {
        Button {
            appState.pendingWikiId = current.id
            NotificationCenter.default.post(name: .openWiki, object: nil)
        } label: {
            Label("나의 위키에서 열기", systemImage: "arrow.up.forward.square")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(.top, 4)
    }

    private func load() {
        if let refreshed = try? appState.wikiRepository.fetch(id: wiki.id) {
            current = refreshed
            markdown = appState.wikiRepository.readMarkdown(refreshed)
        }
    }

    /// 헤더에서 제목을 이미 보여주므로 본문 H1은 제거(중복 방지).
    private func stripH1(_ md: String) -> String {
        var lines = md.components(separatedBy: "\n")
        if let first = lines.first, first.hasPrefix("# ") {
            lines.removeFirst()
            while lines.first?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeFirst() }
        }
        return lines.joined(separator: "\n")
    }
}
