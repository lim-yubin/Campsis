import SwiftUI

struct MarkdownTextView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let content):
            Text(inlineMarkdown(content))
                .font(headingFont(level))
                .fontWeight(.semibold)
                .padding(.top, level == 1 ? 6 : 3)

        case .paragraph(let content):
            Text(inlineMarkdown(content))
                .font(.body)

        case .listItem(let content, let ordered, let index):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(ordered ? "\(index)." : "•")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 20, alignment: .trailing)
                Text(inlineMarkdown(content))
                    .font(.body)
            }

        case .codeBlock(let content):
            Text(content)
                .font(.system(.callout, design: .monospaced))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.textBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 6))

        case .divider:
            Divider()
                .padding(.vertical, 4)
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .title2
        case 2: return .title3
        default: return .headline
        }
    }

    private func inlineMarkdown(_ text: String) -> AttributedString {
        do {
            return try AttributedString(
                markdown: text,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            )
        } catch {
            return AttributedString(text)
        }
    }

    private func parseBlocks() -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = text.components(separatedBy: "\n")
        var i = 0
        var orderedIndex = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                i += 1
                orderedIndex = 0
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
                blocks.append(.codeBlock(codeLines.joined(separator: "\n")))
                orderedIndex = 0
                continue
            }

            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                blocks.append(.divider)
                i += 1
                orderedIndex = 0
                continue
            }

            if let headingMatch = trimmed.headingLevel() {
                blocks.append(.heading(headingMatch.level, headingMatch.content))
                i += 1
                orderedIndex = 0
                continue
            }

            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let content = String(trimmed.dropFirst(2))
                blocks.append(.listItem(content, ordered: false, index: 0))
                i += 1
                orderedIndex = 0
                continue
            }

            if let orderedMatch = trimmed.orderedListItem() {
                orderedIndex += 1
                blocks.append(.listItem(orderedMatch, ordered: true, index: orderedIndex))
                i += 1
                continue
            }

            var paragraphLines: [String] = [trimmed]
            i += 1
            while i < lines.count {
                let nextLine = lines[i].trimmingCharacters(in: .whitespaces)
                if nextLine.isEmpty || nextLine.hasPrefix("#") || nextLine.hasPrefix("```")
                    || nextLine.hasPrefix("- ") || nextLine.hasPrefix("* ")
                    || nextLine == "---" || nextLine == "***"
                    || nextLine.orderedListItem() != nil {
                    break
                }
                paragraphLines.append(nextLine)
                i += 1
            }
            blocks.append(.paragraph(paragraphLines.joined(separator: " ")))
            orderedIndex = 0
        }

        return blocks
    }
}

private enum MarkdownBlock {
    case heading(Int, String)
    case paragraph(String)
    case listItem(String, ordered: Bool, index: Int)
    case codeBlock(String)
    case divider
}

private extension String {
    func headingLevel() -> (level: Int, content: String)? {
        var level = 0
        var idx = startIndex
        while idx < endIndex && self[idx] == "#" && level < 6 {
            level += 1
            idx = index(after: idx)
        }
        guard level > 0, idx < endIndex, self[idx] == " " else { return nil }
        let content = String(self[index(after: idx)...])
        return (level, content)
    }

    func orderedListItem() -> String? {
        guard let dotIdx = firstIndex(of: ".") else { return nil }
        let prefix = self[startIndex..<dotIdx]
        guard prefix.allSatisfy(\.isNumber), !prefix.isEmpty else { return nil }
        let afterDot = index(after: dotIdx)
        guard afterDot < endIndex, self[afterDot] == " " else { return nil }
        return String(self[index(after: afterDot)...])
    }
}
