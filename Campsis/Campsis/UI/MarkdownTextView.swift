import SwiftUI
import AppKit

/// 정리본 복사에 사용하는 변환 헬퍼. 마크다운 원문 복사와 서식을 제거한 일반 텍스트 복사를 지원한다.
enum MarkdownClipboard {
    /// 마크다운 원문을 그대로 클립보드에 복사.
    static func copyMarkdown(_ markdown: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(markdown, forType: .string)
    }

    /// 마크다운 서식을 제거한 일반 텍스트로 복사.
    static func copyPlain(_ markdown: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(plainText(from: markdown), forType: .string)
    }

    /// 헤딩/굵게/인라인코드/목록/링크/구분선 등의 서식을 제거해 사람이 읽기 좋은 텍스트로 변환.
    static func plainText(from markdown: String) -> String {
        var lines: [String] = []
        var inFence = false
        for raw in markdown.components(separatedBy: "\n") {
            var line = raw
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") { inFence.toggle(); continue }
            if inFence { lines.append(line); continue }
            if trimmed == "---" || trimmed == "***" || trimmed == "___" { lines.append(""); continue }
            // 헤딩 마커 제거
            if let hashEnd = trimmed.range(of: #"^#{1,6}\s+"#, options: .regularExpression) {
                line = String(trimmed[hashEnd.upperBound...])
            } else {
                line = trimmed
            }
            // 목록 마커를 불릿/번호로 정리
            line = line.replacingOccurrences(of: #"^[-*]\s+"#, with: "• ", options: .regularExpression)
            // 링크 [텍스트](url) → 텍스트
            line = line.replacingOccurrences(of: #"\[([^\]]+)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
            // 굵게/기울임/인라인코드 마커 제거
            line = line.replacingOccurrences(of: "**", with: "")
            line = line.replacingOccurrences(of: "__", with: "")
            line = line.replacingOccurrences(of: "`", with: "")
            lines.append(line)
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - 공용 복사 토스트

/// "복사되었습니다" 같은 짧은 알림을 화면 하단에 잠깐 띄우는 공용 modifier.
/// 상세/미리보기/채팅 등 복사 어피던스를 일관되게 만든다.
struct CopyToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message {
                    Label(message, systemImage: "checkmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .overlay(Capsule().stroke(.quaternary, lineWidth: 1))
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: message)
            .onChange(of: message) { _, newValue in
                guard newValue != nil else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { message = nil }
                }
            }
    }
}

extension View {
    /// 복사 완료 토스트를 표시. `message`에 문자열을 넣으면 잠깐 떴다 사라진다.
    func copyToast(_ message: Binding<String?>) -> some View {
        modifier(CopyToastModifier(message: message))
    }
}

struct MarkdownTextView: NSViewRepresentable {
    let text: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, NSTextViewDelegate {
        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            let url: URL?
            switch link {
            case let u as URL: url = u
            case let s as String: url = URL(string: s)
            default: url = nil
            }
            if let url { NSWorkspace.shared.open(url); return true }
            return false
        }
    }

    func makeNSView(context: Context) -> IntrinsicScrollView {
        let textView = NSTextView()
        _ = textView.layoutManager   // TextKit 1 강제(표/NSTextTable 렌더링에 필요)
        textView.delegate = context.coordinator
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isRichText = true
        textView.linkTextAttributes = [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .cursor: NSCursor.pointingHand,
        ]
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

            // GFM 표: 헤더 행 + 구분 행(| --- | --- |) 감지
            if let table = parseTable(lines, from: i, bodyFont: bodyFont, bodyColor: bodyColor) {
                result.append(table.attr)
                result.append(NSAttributedString(string: "\n", attributes: [.font: bodyFont]))
                i = table.next
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
            if remaining.hasPrefix("![") {
                // 이미지: ![alt](src)
                if let link = parseMarkdownLink(remaining.dropFirst()) {
                    if let image = loadInlineImage(link.url) {
                        let attachment = NSTextAttachment()
                        attachment.image = image
                        let maxW: CGFloat = 360
                        let s = image.size
                        let scale = s.width > maxW ? maxW / s.width : 1
                        attachment.bounds = CGRect(x: 0, y: 0, width: s.width * scale, height: s.height * scale)
                        result.append(NSAttributedString(attachment: attachment))
                    } else {
                        let alt = link.label.isEmpty ? link.url : link.label
                        result.append(NSAttributedString(string: "🖼 \(alt)", attributes: baseAttrs))
                    }
                    remaining = link.rest
                } else {
                    result.append(NSAttributedString(string: "!", attributes: baseAttrs))
                    remaining = remaining.dropFirst()
                }
            } else if remaining.hasPrefix("[") {
                // 링크: [텍스트](url)
                if let link = parseMarkdownLink(remaining) {
                    var attrs = baseAttrs
                    if let url = URL(string: link.url) {
                        attrs[.link] = url
                        attrs[.foregroundColor] = NSColor.linkColor
                        attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
                    }
                    result.append(NSAttributedString(string: link.label, attributes: attrs))
                    remaining = link.rest
                } else {
                    result.append(NSAttributedString(string: "[", attributes: baseAttrs))
                    remaining = remaining.dropFirst()
                }
            } else if remaining.hasPrefix("**") || remaining.hasPrefix("__") {
                let marker = String(remaining.prefix(2))
                remaining = remaining.dropFirst(2)
                if let endRange = remaining.range(of: marker) {
                    let bold = String(remaining[..<endRange.lowerBound])
                    var attrs = baseAttrs
                    if let font = attrs[.font] as? NSFont {
                        attrs[.font] = NSFont.systemFont(ofSize: font.pointSize, weight: .bold)
                    }
                    // 굵게 내부의 URL/링크도 처리되도록 재귀 렌더
                    result.append(renderInline(bold, baseAttrs: attrs))
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
            } else if remaining.hasPrefix("http://") || remaining.hasPrefix("https://") {
                // 평문 URL 자동 링크화
                var raw = ""
                while let c = remaining.first, !c.isWhitespace {
                    raw.append(c)
                    remaining = remaining.dropFirst()
                }
                // 흔한 후행 문장부호는 URL에서 제외해 뒤에 평문으로 붙인다
                let trailingSet = Set(")].,;:!?\"'》」』")
                var trailing = ""
                while let last = raw.last, trailingSet.contains(last) {
                    trailing.insert(last, at: trailing.startIndex)
                    raw.removeLast()
                }
                if let url = URL(string: raw) {
                    var attrs = baseAttrs
                    attrs[.link] = url
                    attrs[.foregroundColor] = NSColor.linkColor
                    attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
                    result.append(NSAttributedString(string: raw, attributes: attrs))
                } else {
                    result.append(NSAttributedString(string: raw, attributes: baseAttrs))
                }
                if !trailing.isEmpty {
                    result.append(NSAttributedString(string: trailing, attributes: baseAttrs))
                }
            } else {
                var chunk = ""
                while !remaining.isEmpty
                    && !remaining.hasPrefix("**") && !remaining.hasPrefix("__")
                    && !remaining.hasPrefix("`") && !remaining.hasPrefix("![")
                    && !remaining.hasPrefix("[")
                    && !remaining.hasPrefix("http://") && !remaining.hasPrefix("https://") {
                    chunk.append(remaining.removeFirst())
                }
                result.append(NSAttributedString(string: chunk, attributes: baseAttrs))
            }
        }

        return result
    }

    /// `[label](url)` 형태를 파싱. `s`는 여는 대괄호 `[`로 시작해야 한다.
    private func parseMarkdownLink(_ s: Substring) -> (label: String, url: String, rest: Substring)? {
        guard s.hasPrefix("[") else { return nil }
        let afterOpen = s.dropFirst()
        guard let close = afterOpen.firstIndex(of: "]") else { return nil }
        let label = String(afterOpen[..<close])
        let afterLabel = afterOpen.index(after: close)
        guard afterLabel < afterOpen.endIndex, afterOpen[afterLabel] == "(" else { return nil }
        let afterParen = afterOpen.index(after: afterLabel)
        guard let closeParen = afterOpen[afterParen...].firstIndex(of: ")") else { return nil }
        let url = String(afterOpen[afterParen..<closeParen]).trimmingCharacters(in: .whitespaces)
        let rest = afterOpen[afterOpen.index(after: closeParen)...]
        return (label, url, rest)
    }

    /// 로컬 이미지(파일 경로/파일 URL)만 인라인으로 로드. 원격(http)은 동기 렌더를 피해 생략(대체 텍스트).
    private func loadInlineImage(_ src: String) -> NSImage? {
        if src.hasPrefix("http://") || src.hasPrefix("https://") { return nil }
        if let url = URL(string: src), url.isFileURL, let img = NSImage(contentsOf: url) { return img }
        let expanded = (src as NSString).expandingTildeInPath
        if FileManager.default.fileExists(atPath: expanded) { return NSImage(contentsOfFile: expanded) }
        let abs = AppPaths.absoluteURL(from: src)
        if FileManager.default.fileExists(atPath: abs.path) { return NSImage(contentsOf: abs) }
        return nil
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

    // MARK: - 표(GFM 파이프 테이블)

    /// `start`에서 시작하는 GFM 표를 NSTextTable로 렌더링. 표가 아니면 nil.
    private func parseTable(_ lines: [String], from start: Int,
                            bodyFont: NSFont, bodyColor: NSColor) -> (attr: NSAttributedString, next: Int)? {
        guard start + 1 < lines.count else { return nil }
        let header = lines[start].trimmingCharacters(in: .whitespaces)
        guard header.contains("|"), isTableSeparator(lines[start + 1].trimmingCharacters(in: .whitespaces)) else {
            return nil
        }

        var rows: [[String]] = [splitTableRow(header)]
        var idx = start + 2
        while idx < lines.count {
            let line = lines[idx].trimmingCharacters(in: .whitespaces)
            if line.isEmpty || !line.contains("|") { break }
            rows.append(splitTableRow(line))
            idx += 1
        }

        let columns = rows.map { $0.count }.max() ?? 0
        guard columns > 0 else { return nil }

        let table = NSTextTable()
        table.numberOfColumns = columns
        table.hidesEmptyCells = false

        let out = NSMutableAttributedString()
        for (r, row) in rows.enumerated() {
            for c in 0..<columns {
                let text = c < row.count ? row[c] : ""
                let block = NSTextTableBlock(table: table, startingRow: r, rowSpan: 1,
                                             startingColumn: c, columnSpan: 1)
                block.setBorderColor(.separatorColor)
                block.setWidth(1, type: .absoluteValueType, for: .border)
                block.setWidth(6, type: .absoluteValueType, for: .padding)
                if r == 0 {
                    block.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.4)
                }
                let para = NSMutableParagraphStyle()
                para.textBlocks = [block]
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: r == 0 ? NSFont.systemFont(ofSize: 14, weight: .semibold) : bodyFont,
                    .foregroundColor: bodyColor,
                    .paragraphStyle: para,
                ]
                let cell = NSMutableAttributedString(attributedString: renderInline(text, baseAttrs: attrs))
                cell.append(NSAttributedString(string: "\n", attributes: attrs))
                out.append(cell)
            }
        }
        return (out, idx)
    }

    /// `| --- | :--: |` 같은 표 구분 행인지 판별.
    private func isTableSeparator(_ line: String) -> Bool {
        var s = line
        if s.hasPrefix("|") { s.removeFirst() }
        if s.hasSuffix("|") { s.removeLast() }
        let cells = s.split(separator: "|", omittingEmptySubsequences: false)
        guard !cells.isEmpty else { return false }
        for cell in cells {
            let t = cell.trimmingCharacters(in: .whitespaces)
            if t.isEmpty || !t.contains("-") { return false }
            if !t.allSatisfy({ $0 == "-" || $0 == ":" }) { return false }
        }
        return true
    }

    /// 표의 한 행을 셀 배열로 분리(앞뒤 파이프 제거).
    private func splitTableRow(_ line: String) -> [String] {
        var s = line.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("|") { s.removeFirst() }
        if s.hasSuffix("|") { s.removeLast() }
        return s.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
