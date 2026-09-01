import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let sources: [Source]
    @Environment(AppState.self) private var appState
    @State private var showSources = false
    @State private var copied = false

    /// 출처(메모리)가 연결된 답변만 마크다운으로 렌더하고 복사 버튼을 제공한다.
    private var isMarkdownAnswer: Bool {
        message.role == .assistant && !sources.isEmpty
    }

    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
            bubble

            if isMarkdownAnswer {
                sourcesToggle
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        .padding(.horizontal)
    }

    private var bubble: some View {
        Group {
            if isMarkdownAnswer {
                MarkdownTextView(text: LunaChatEngine.stripCitations(message.content))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 28)   // 우상단 복사 버튼과 겹치지 않도록
                    .overlay(alignment: .topTrailing) { copyButton }
            } else if message.role == .assistant {
                // 메모리와 무관한 일반 답변: 평문 채팅
                Text(LunaChatEngine.stripCitations(message.content))
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
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

    @ViewBuilder
    private var sourcesToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { showSources.toggle() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                Text("출처 \(sources.count)개")
                Image(systemName: showSources ? "chevron.up" : "chevron.down")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)

        if showSources {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(sources) { source in
                    Button {
                        appState.inspectorSource = source
                        appState.inspectorMode = .source
                        appState.showInspector = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: iconName(for: source.type))
                                .foregroundStyle(.secondary)
                                .frame(width: 18)
                            Text(sourceTitle(source))
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: 440, alignment: .leading)
        }
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
        if let title = source.windowTitle, !title.isEmpty { return title }
        if let content = source.content, !content.isEmpty { return String(content.prefix(50)) }
        return source.type.rawValue.capitalized
    }
}
