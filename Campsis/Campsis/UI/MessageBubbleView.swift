import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let sources: [Source]
    @Environment(AppState.self) private var appState
    @State private var showSources = false
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == .assistant {
                avatar
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                bubble

                if message.role == .assistant {
                    HStack(spacing: 12) {
                        copyButton

                        if !sources.isEmpty {
                            sourcesToggle
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .user {
                avatar
            }
        }
        .padding(.horizontal)
    }

    private var avatar: some View {
        Image(systemName: message.role == .user ? "person.circle.fill" : "brain.head.profile")
            .font(.title2)
            .foregroundStyle(message.role == .user ? Color.chatAccent : Color.assistantAccent)
            .frame(width: 28, height: 28)
            .accessibilityLabel(message.role == .user ? "나" : "AI")
    }

    private var bubble: some View {
        Group {
            if message.role == .assistant {
                MarkdownTextView(text: LunaChatEngine.stripCitations(message.content))
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
        .frame(maxWidth: 600, alignment: message.role == .user ? .trailing : .leading)
    }

    private var copyButton: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(message.content, forType: .string)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                Text(copied ? "복사됨" : "복사")
            }
            .font(.subheadline)
            .foregroundStyle(copied ? .green : .secondary)
        }
        .buttonStyle(.plain)
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
