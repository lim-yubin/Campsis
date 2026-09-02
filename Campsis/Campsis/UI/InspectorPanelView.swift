import SwiftUI

/// 오른쪽 분할 패널. 채팅 답변의 출처 정리본을 미리 보거나, 전체 메모리 목록을
/// 컴팩트하게 탐색해 메모리와 채팅을 나란히 볼 수 있게 한다. (읽기 전용 미리보기)
struct InspectorPanelView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            Picker("보기", selection: $appState.inspectorMode) {
                Text("정리본").tag(InspectorMode.source)
                Text("메모리").tag(InspectorMode.memories)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            switch appState.inspectorMode {
            case .source:
                if let source = appState.inspectorSource {
                    SourcePreviewView(source: source)
                } else {
                    ContentUnavailableView(
                        "출처를 선택하세요",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("채팅 답변 하단의 출처를 클릭하면\n정리본이 여기에 표시됩니다.")
                    )
                }
            case .memories:
                InspectorMemoriesList()
            }
        }
        // 폭은 인스펙터 컬럼(.inspectorColumnWidth) 한 곳에서만 관리한다.
        // 여기서 minWidth/idealWidth를 또 지정하면 리사이즈 시 두 제약이 충돌해 튕김이 발생.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .help("메모리를 화면 분할로 함께 보기")
    }
}

/// 인스펙터에서 보여주는 읽기 전용 정리본. 정리본(MD)이 없으면 원본 콘텐츠로 폴백한다.
struct SourcePreviewView: View {
    let source: Source
    @Environment(AppState.self) private var appState
    @State private var markdown: String?
    @State private var loaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // A1: 이미지/스크린샷 소스는 캡처본을 상단에 노출
                if let image = previewImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 260)
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
        .task(id: source.id) { load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
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
        }
    }

    // B2: 정리본 복사 — 마크다운 원문 / 일반 텍스트
    @ViewBuilder
    private var copyMenu: some View {
        if let md = markdown, !md.isEmpty {
            Menu {
                Button("마크다운으로 복사") { MarkdownClipboard.copyMarkdown(md) }
                Button("일반 텍스트로 복사") { MarkdownClipboard.copyPlain(md) }
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
    @Environment(AppState.self) private var appState
    @State private var sources: [Source] = []

    var body: some View {
        List {
            // A4: 메모리 메뉴와 동일한 MemoryRowView를 재사용해 콘텐츠를 크고 명확하게 표시
            ForEach(sources) { source in
                MemoryRowView(source: source)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.inspectorSource = source
                        appState.inspectorMode = .source
                    }
                    .listRowInsets(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
            }
        }
        .listStyle(.inset)
        .overlay {
            if sources.isEmpty {
                ContentUnavailableView(
                    "메모리 없음",
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
