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
        .frame(minWidth: 280, idealWidth: 360)
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
                header

                if let md = markdown, !md.isEmpty {
                    MarkdownTextView(text: md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if let content = source.content, !content.isEmpty {
                    Text(content)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if loaded {
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
        VStack(alignment: .leading, spacing: 4) {
            if let title = source.windowTitle, !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
            }
            Text(source.capturedAt.formatted(.dateTime.year().month().day().hour().minute()))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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
            ForEach(sources) { source in
                Button {
                    appState.inspectorSource = source
                    appState.inspectorMode = .source
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: iconName(for: source.type))
                            .foregroundStyle(.secondary)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title(for: source))
                                .font(.subheadline)
                                .lineLimit(1)
                            Text(source.capturedAt.formatted(.dateTime.month().day().hour().minute()))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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

    private func title(for source: Source) -> String {
        if let content = source.content, !content.isEmpty { return String(content.prefix(60)) }
        if let summary = source.summary, !summary.isEmpty { return summary }
        if let title = source.windowTitle, !title.isEmpty { return title }
        return source.type.rawValue.capitalized
    }

    private func iconName(for type: SourceType) -> String {
        switch type {
        case .selectedText: return "text.quote"
        case .screenshot: return "camera"
        case .note: return "note.text"
        case .voice: return "waveform"
        case .file: return "doc"
        }
    }
}
