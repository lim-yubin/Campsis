import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let sources: [Source]
    @Environment(AppState.self) private var appState
    @State private var showAllSources = false
    @State private var copied = false

    private let maxVisibleSources = 4

    /// 출처(메모리)가 연결된 답변만 마크다운으로 렌더하고 복사 버튼을 제공한다.
    private var isMarkdownAnswer: Bool {
        message.role == .assistant && !sources.isEmpty
    }

    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
            bubble

            if isMarkdownAnswer {
                sourcesChips
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        .padding(.horizontal)
    }

    private var bubble: some View {
        Group {
            if message.role == .assistant {
                // 답변은 항상 MarkdownTextView로 렌더(평문 산문도 동일하게 보이며 URL 링크가 확실히 동작).
                // 복사 버튼은 출처(메모리)가 연결된 답변에만 우상단에 표시.
                MarkdownTextView(text: LunaChatEngine.stripCitations(message.content))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, isMarkdownAnswer ? 28 : 0)
                    .overlay(alignment: .topTrailing) {
                        if isMarkdownAnswer { copyButton }
                    }
            } else {
                Text(message.content)
                    .font(.body)
                    .textSelection(.enabled)
            }
        }
        .padding(14)
        .background(
            message.role == .user
                ? Color.userBubbleBackground
                : Color.assistantBubbleBackground,
            in: RoundedRectangle(cornerRadius: 12)
        )
        .frame(
            maxWidth: message.role == .user ? 600 : .infinity,
            alignment: message.role == .user ? .trailing : .leading
        )
    }

    private var copyButton: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(message.content, forType: .string)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.caption)
                .foregroundStyle(copied ? .green : .secondary)
                .padding(6)
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .help(copied ? "복사됨" : "복사")
    }

    /// 답변 하단에 항상 보이는 컴팩트 출처 칩 행. (관련도 순서 유지)
    @ViewBuilder
    private var sourcesChips: some View {
        let visible = showAllSources ? sources : Array(sources.prefix(maxVisibleSources))
        let overflow = sources.count - visible.count

        FlowLayout(spacing: 6) {
            ForEach(visible) { source in
                sourceChip(source)
            }
            if overflow > 0 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showAllSources = true }
                } label: {
                    Text("+\(overflow)개 더보기")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: 460, alignment: .leading)
    }

    private func sourceChip(_ source: Source) -> some View {
        Button {
            appState.inspectorSource = source
            appState.inspectorMode = .source
            appState.showInspector = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: iconName(for: source.type))
                    .font(.caption2)
                    .foregroundStyle(isPreviewing(source) ? Color.accentColor : .secondary)
                Text(sourceTitle(source))
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .frame(maxWidth: 220, alignment: .leading)
            .background(
                isPreviewing(source) ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12),
                in: Capsule()
            )
            .overlay(
                Capsule().stroke(isPreviewing(source) ? Color.accentColor : Color.clear, lineWidth: 1)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(source.displayTitle)
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

    private func sourceTitle(_ source: Source) -> String {
        source.displayTitle
    }

    /// 현재 인스펙터에서 미리보기 중인 출처인지.
    private func isPreviewing(_ source: Source) -> Bool {
        appState.showInspector
            && appState.inspectorMode == .source
            && appState.inspectorSource?.id == source.id
    }
}
