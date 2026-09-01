import SwiftUI
import AppKit

struct ChatInputView: View {
    @Binding var text: String
    let isLoading: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Enter = 전송, Shift+Enter = 줄바꿈 (C1)
            ChatTextEditor(text: $text, placeholder: "기억에게 무엇이든 물어보세요...") {
                sendIfReady()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text("기억에게 무엇이든 물어보세요...")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
            }

            Button {
                if isLoading { onStop() } else { sendIfReady() }
            } label: {
                Image(systemName: isLoading ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.title)
            }
            .buttonStyle(.plain)
            .foregroundStyle(isLoading ? Color.red : (canSend ? Color.chatAccent : Color.secondary))
            .disabled(!isLoading && !canSend)
            .accessibilityLabel(isLoading ? "생성 중지" : "보내기")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    private func sendIfReady() {
        guard canSend else { return }
        onSend()
    }
}

/// 세로로 늘어나는 채팅 입력창. Enter는 전송, Shift+Enter는 줄바꿈으로 동작한다.
struct ChatTextEditor: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void

    // 폰트 한 줄 높이를 기준으로 초기(1줄)·최대(10줄) 높이를 계산한다.
    private static let font = NSFont.systemFont(ofSize: 14)
    private static let lineHeight = ceil(NSLayoutManager().defaultLineHeight(for: font))
    private var minHeight: CGFloat { Self.lineHeight }              // 딱 한 줄
    private var maxHeight: CGFloat { Self.lineHeight * 10 }         // 최대 10줄, 이후 스크롤

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> IntrinsicScrollView {
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = Self.font
        textView.drawsBackground = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]
        textView.string = text

        let scrollView = IntrinsicScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.documentView = textView
        scrollView.minHeight = minHeight
        scrollView.maxHeight = maxHeight

        context.coordinator.textView = textView
        DispatchQueue.main.async { context.coordinator.updateHeight(scrollView) }
        return scrollView
    }

    func updateNSView(_ scrollView: IntrinsicScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        context.coordinator.placeholder = placeholder
        DispatchQueue.main.async { context.coordinator.updateHeight(scrollView) }
        scrollView.needsDisplay = true
    }

    /// SwiftUI에 정확한 높이를 알려준다. 이게 없으면 스크롤뷰가 남는 세로 공간을 모두 채운다.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: IntrinsicScrollView, context: Context) -> CGSize? {
        let width = proposal.width ?? nsView.frame.width
        guard let textView = nsView.documentView as? NSTextView,
              let container = textView.textContainer,
              let layoutManager = textView.layoutManager, width > 0 else {
            return CGSize(width: proposal.width ?? 0, height: minHeight)
        }
        container.containerSize = CGSize(width: width, height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: container)
        let used = layoutManager.usedRect(for: container).height
        let clamped = min(max(used.rounded(.up), minHeight), maxHeight)
        return CGSize(width: width, height: clamped)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ChatTextEditor
        weak var textView: NSTextView?
        var placeholder: String

        init(_ parent: ChatTextEditor) {
            self.parent = parent
            self.placeholder = parent.placeholder
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            if let scrollView = textView.enclosingScrollView as? IntrinsicScrollView {
                updateHeight(scrollView)
            }
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                let shift = NSApp.currentEvent?.modifierFlags.contains(.shift) ?? false
                if shift {
                    // 기본 동작(줄바꿈 삽입)을 그대로 허용
                    return false
                }
                parent.onSubmit()
                return true
            }
            return false
        }

        func updateHeight(_ scrollView: IntrinsicScrollView) {
            guard let textView, let container = textView.textContainer else { return }
            textView.layoutManager?.ensureLayout(for: container)
            let used = textView.layoutManager?.usedRect(for: container).height ?? scrollView.minHeight
            let clamped = min(max(used, scrollView.minHeight), scrollView.maxHeight)
            scrollView.hasVerticalScroller = used > scrollView.maxHeight
            if scrollView.contentHeight != clamped {
                scrollView.contentHeight = clamped
                scrollView.invalidateIntrinsicContentSize()
            }
        }
    }

    final class IntrinsicScrollView: NSScrollView {
        var contentHeight: CGFloat = ChatTextEditor.lineHeight
        var minHeight: CGFloat = ChatTextEditor.lineHeight
        var maxHeight: CGFloat = ChatTextEditor.lineHeight * 10

        override var intrinsicContentSize: NSSize {
            NSSize(width: NSView.noIntrinsicMetric, height: contentHeight)
        }
    }
}
