import SwiftUI

/// 위키 상세 — 종합 페이지 + 구성 메모 + 관련 위키 (Phase 8.7).
struct WikiDetailView: View {
    let wiki: Wiki

    @Environment(AppState.self) private var appState
    @State private var current: Wiki
    @State private var markdown: String?
    @State private var members: [Source] = []
    @State private var related: [Wiki] = []
    @State private var toast: String?

    init(wiki: Wiki) {
        self.wiki = wiki
        _current = State(initialValue: wiki)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                Divider()
                pageSection
                if !related.isEmpty { relatedSection }
                membersSection
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(current.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if markdown != nil {
                    Menu {
                        Button("마크다운 복사") {
                            MarkdownClipboard.copyMarkdown(markdownForCopy)
                            showToast("마크다운 복사됨")
                        }
                        Button("일반 텍스트 복사") {
                            MarkdownClipboard.copyPlain(markdownForCopy)
                            showToast("복사됨")
                        }
                    } label: {
                        Label("복사", systemImage: "doc.on.doc")
                    }
                }
            }
        }
        .overlay(alignment: .bottom) { toastView }
        .onAppear(perform: load)
        .onReceive(NotificationCenter.default.publisher(for: .wikiUpdated)) { _ in load() }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "book.closed.fill")
                    .foregroundStyle(Color.chatAccent)
                Text(current.title)
                    .font(.largeTitle.weight(.semibold))
                if current.markdownStatus == .processing || current.markdownStatus == .pending {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.small)
                        Text("정리 중")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                }
            }
            if let summary = current.summary, !summary.isEmpty {
                Text(summary)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            Text("메모 \(current.memberCount)개로 만들어졌어요 · \(current.updatedAt.formatted(.dateTime.year().month().day()))")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var pageSection: some View {
        if let markdown, !markdown.isEmpty {
            MarkdownTextView(text: strippedMarkdown(markdown))
        } else if current.markdownStatus == .pending || current.markdownStatus == .processing {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("종합 문서를 작성하고 있어요. 잠시만 기다려 주세요.")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        } else {
            Text("아직 종합 내용이 없습니다.")
                .foregroundStyle(.secondary)
        }
    }

    private var relatedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("관련 위키", systemImage: "link")
                .font(.headline)
                .foregroundStyle(.secondary)
            FlowChips(items: related, id: \.id) { w in
                NavigationLink(value: w) {
                    HStack(spacing: 4) {
                        Image(systemName: "book.closed.fill").font(.system(size: 9))
                        Text(w.title).font(.subheadline)
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(Color.chatAccent.opacity(0.14), in: Capsule())
                    .foregroundStyle(Color.chatAccent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("구성 메모 \(members.count)개", systemImage: "note.text")
                .font(.headline)
                .foregroundStyle(.secondary)
            if members.isEmpty {
                Text("구성 메모가 없습니다.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            } else {
                VStack(spacing: 6) {
                    ForEach(members) { source in
                        memberRow(source)
                    }
                }
            }
        }
    }

    private func memberRow(_ source: Source) -> some View {
        Button {
            appState.inspectorSource = source
            appState.inspectorMode = .source
            withAnimation { appState.showInspector = true }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: memberIcon(source))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.displayTitle).font(.body).lineLimit(1)
                    Text(source.capturedAt.formatted(.dateTime.month().day().hour().minute()))
                        .font(.caption).foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
                Image(systemName: "sidebar.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            Text(toast)
                .font(.caption)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Load / Actions

    private func load() {
        if let refreshed = try? appState.wikiRepository.fetch(id: wiki.id) {
            current = refreshed
            markdown = appState.wikiRepository.readMarkdown(refreshed)
        }
        do {
            let ids = try appState.wikiRepository.noteIds(forWiki: wiki.id)
            members = ids.compactMap { try? appState.sourceRepository.fetch(id: $0) }
                .sorted { $0.capturedAt > $1.capturedAt }
            let relatedIds = try appState.wikiRepository.relatedWikiIds(forWiki: wiki.id)
            related = relatedIds.compactMap { try? appState.wikiRepository.fetch(id: $0) }
        } catch {
            NSLog("[Campsis] Failed to load wiki detail: \(error)")
        }
    }

    private var markdownForCopy: String { markdown ?? "" }

    private func showToast(_ label: String) {
        withAnimation { toast = label }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { toast = nil }
        }
    }

    /// 페이지 상단 H1 제목은 헤더에서 이미 보여주므로 본문에선 제거(중복 방지).
    private func strippedMarkdown(_ md: String) -> String {
        var lines = md.components(separatedBy: "\n")
        if let first = lines.first, first.hasPrefix("# ") {
            lines.removeFirst()
            while lines.first?.trimmingCharacters(in: .whitespaces).isEmpty == true { lines.removeFirst() }
        }
        return lines.joined(separator: "\n")
    }

    private func memberIcon(_ source: Source) -> String {
        switch source.type {
        case .selectedText: return "text.quote"
        case .screenshot: return "camera"
        case .note: return "note.text"
        case .voice: return "waveform"
        case .file: return "doc"
        }
    }
}

/// 간단한 가로 래핑 칩 컨테이너(관련 위키용).
private struct FlowChips<Item, ID: Hashable, Content: View>: View {
    let items: [Item]
    let id: KeyPath<Item, ID>
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items, id: id) { content($0) }
            }
        }
    }
}
