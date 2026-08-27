import SwiftUI
import AppKit

struct MarkdownTextView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> IntrinsicScrollView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isRichText = true
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        let scrollView = IntrinsicScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.documentView = textView

        textView.textStorage?.setAttributedString(renderMarkdown(text))

        DispatchQueue.main.async {
            Self.updateHeight(scrollView: scrollView, textView: textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: IntrinsicScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        textView.textStorage?.setAttributedString(renderMarkdown(text))
        DispatchQueue.main.async {
            Self.updateHeight(scrollView: scrollView, textView: textView)
        }
    }

    private static func updateHeight(scrollView: IntrinsicScrollView, textView: NSTextView) {
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        let height = textView.layoutManager?.usedRect(for: textView.textContainer!).height ?? 0
        scrollView.contentHeight = max(height + 2, 20)
        scrollView.invalidateIntrinsicContentSize()
    }

    class IntrinsicScrollView: NSScrollView {
        var contentHeight: CGFloat = 20

        override var intrinsicContentSize: NSSize {
            NSSize(width: NSView.noIntrinsicMetric, height: contentHeight)
        }
    }

    private func renderMarkdown(_ markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: "\n")
        let bodyFont = NSFont.systemFont(ofSize: 14)
        let bodyColor = NSColor.labelColor
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                result.append(NSAttributedString(string: "\n", attributes: [.font: bodyFont]))
                i += 1
                continue
            }

            if trimmed.hasPrefix("```") {
                i += 1
                var codeLines: [String] = []
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                i += 1
                let code = codeLines.joined(separator: "\n")
                let codeAttr: [NSAttributedString.Key: Any] = [
                    .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                    .foregroundColor: bodyColor,
                    .backgroundColor: NSColor.textBackgroundColor.withAlphaComponent(0.5)
                ]
                result.append(NSAttributedString(string: code + "\n", attributes: codeAttr))
                continue
            }

            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                result.append(NSAttributedString(string: "\n", attributes: [.font: NSFont.systemFont(ofSize: 6)]))
                i += 1
                continue
            }

            if let heading = parseHeading(trimmed) {
                let fontSize: CGFloat = heading.level == 1 ? 20 : heading.level == 2 ? 17 : 15
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
                    .foregroundColor: bodyColor
                ]
                result.append(renderInline(heading.content, baseAttrs: attrs))
                result.append(NSAttributedString(string: "\n", attributes: attrs))
                i += 1
                continue
            }

            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let content = String(trimmed.dropFirst(2))
                let attrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: bodyColor]
                result.append(NSAttributedString(string: "  • ", attributes: [.font: bodyFont, .foregroundColor: NSColor.secondaryLabelColor]))
                result.append(renderInline(content, baseAttrs: attrs))
                result.append(NSAttributedString(string: "\n", attributes: attrs))
                i += 1
                continue
            }

            if let orderedContent = parseOrderedList(trimmed, at: i, in: lines) {
                let attrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: bodyColor]
                result.append(NSAttributedString(string: "  \(orderedContent.index). ", attributes: [.font: bodyFont, .foregroundColor: NSColor.secondaryLabelColor]))
                result.append(renderInline(orderedContent.content, baseAttrs: attrs))
                result.append(NSAttributedString(string: "\n", attributes: attrs))
                i += 1
                continue
            }

            let attrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: bodyColor]
            result.append(renderInline(trimmed, baseAttrs: attrs))
            result.append(NSAttributedString(string: "\n", attributes: attrs))
            i += 1
        }

        return result
    }

    private func renderInline(_ text: String, baseAttrs: [NSAttributedString.Key: Any]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var remaining = text[...]

        while !remaining.isEmpty {
            if remaining.hasPrefix("**") || remaining.hasPrefix("__") {
                let marker = String(remaining.prefix(2))
                remaining = remaining.dropFirst(2)
                if let endRange = remaining.range(of: marker) {
                    let bold = String(remaining[..<endRange.lowerBound])
                    var attrs = baseAttrs
                    if let font = attrs[.font] as? NSFont {
                        attrs[.font] = NSFont.systemFont(ofSize: font.pointSize, weight: .bold)
                    }
                    result.append(NSAttributedString(string: bold, attributes: attrs))
                    remaining = remaining[endRange.upperBound...]
                } else {
                    result.append(NSAttributedString(string: marker, attributes: baseAttrs))
                }
            } else if remaining.hasPrefix("`") {
                remaining = remaining.dropFirst(1)
                if let endIdx = remaining.firstIndex(of: "`") {
                    let code = String(remaining[..<endIdx])
                    var attrs = baseAttrs
                    attrs[.font] = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
                    attrs[.backgroundColor] = NSColor.textBackgroundColor.withAlphaComponent(0.5)
                    result.append(NSAttributedString(string: code, attributes: attrs))
                    remaining = remaining[remaining.index(after: endIdx)...]
                } else {
                    result.append(NSAttributedString(string: "`", attributes: baseAttrs))
                }
            } else {
                var chunk = ""
                while !remaining.isEmpty && !remaining.hasPrefix("**") && !remaining.hasPrefix("__") && !remaining.hasPrefix("`") {
                    chunk.append(remaining.removeFirst())
                }
                result.append(NSAttributedString(string: chunk, attributes: baseAttrs))
            }
        }

        return result
    }

    private func parseHeading(_ line: String) -> (level: Int, content: String)? {
        var level = 0
        var idx = line.startIndex
        while idx < line.endIndex && line[idx] == "#" && level < 6 {
            level += 1
            idx = line.index(after: idx)
        }
        guard level > 0, idx < line.endIndex, line[idx] == " " else { return nil }
        return (level, String(line[line.index(after: idx)...]))
    }

    private func parseOrderedList(_ line: String, at index: Int, in lines: [String]) -> (index: Int, content: String)? {
        guard let dotIdx = line.firstIndex(of: ".") else { return nil }
        let prefix = line[line.startIndex..<dotIdx]
        guard prefix.allSatisfy(\.isNumber), !prefix.isEmpty else { return nil }
        let afterDot = line.index(after: dotIdx)
        guard afterDot < line.endIndex, line[afterDot] == " " else { return nil }
        let num = Int(prefix) ?? 1
        return (num, String(line[line.index(after: afterDot)...]))
    }
}
