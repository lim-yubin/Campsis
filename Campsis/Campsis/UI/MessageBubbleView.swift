import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let references: [ChatReference]
    @Environment(AppState.self) private var appState
    @State private var showAllSources = false
    @State private var copied = false

    private let maxVisibleSources = 4

    /// 출처(위키/메모)가 연결된 답변만 마크다운으로 렌더하고 복사 버튼을 제공한다.
    private var isMarkdownAnswer: Bool {
        message.role == .assistant && !references.isEmpty
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

    /// 답변 하단에 항상 보이는 컴팩트 출처 칩 행. (위키 우선, 관련도 순서 유지)
    @ViewBuilder
    private var sourcesChips: some View {
        let visible = showAllSources ? references : Array(references.prefix(maxVisibleSources))
        let overflow = references.count - visible.count

        FlowLayout(spacing: 6) {
            ForEach(visible) { ref in
                referenceChip(ref)
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

    private func referenceChip(_ ref: ChatReference) -> some View {
        let active = isActive(ref)
        let tint: Color = ref.kind == .wiki ? .chatAccent : .accentColor
        return Button {
            open(ref)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon(for: ref))
                    .font(.caption2)
                    .foregroundStyle(active ? tint : .secondary)
                Text(kindLabel(ref))
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(tint.opacity(0.16), in: Capsule())
                    .foregroundStyle(tint)
                Text(ref.title)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .frame(maxWidth: 240, alignment: .leading)
            .background(
                active ? tint.opacity(0.18) : Color.secondary.opacity(0.12),
                in: Capsule()
            )
            .overlay(
                Capsule().stroke(active ? tint : Color.clear, lineWidth: 1)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(ref.title)
    }

    /// 출처 클릭: 메모는 인스펙터 미리보기, 위키는 나의 위키에서 열기.
    private func open(_ ref: ChatReference) {
        switch ref.kind {
        case .memo:
            guard let source = try? appState.sourceRepository.fetch(id: ref.id) else { return }
            appState.inspectorSource = source
            appState.inspectorMode = .source
            appState.showInspector = true
        case .wiki:
            appState.pendingWikiId = ref.id
            NotificationCenter.default.post(name: .openWiki, object: nil)
        }
    }

    private func kindLabel(_ ref: ChatReference) -> String {
        ref.kind == .wiki ? "위키" : "메모"
    }

    private func icon(for ref: ChatReference) -> String {
        ref.kind == .wiki ? "book.closed.fill" : "note.text"
    }

    /// 현재 인스펙터에서 미리보기 중인 메모인지(하이라이트).
    private func isActive(_ ref: ChatReference) -> Bool {
        ref.kind == .memo
            && appState.showInspector
            && appState.inspectorMode == .source
            && appState.inspectorSource?.id == ref.id
    }
}
