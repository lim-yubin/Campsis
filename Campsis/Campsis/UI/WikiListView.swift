import SwiftUI

/// 나의 위키 — 토픽 허브 리스트 + 상세 (Phase 8.7).
struct WikiListView: View {
    @Environment(AppState.self) private var appState
    @State private var wikis: [Wiki] = []
    @State private var relatedCounts: [String: Int] = [:]

    var body: some View {
        NavigationStack {
            Group {
                if wikis.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("나의 위키")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    InspectorToggleButton()
                }
            }
            .navigationDestination(for: Wiki.self) { wiki in
                WikiDetailView(wiki: wiki)
            }
        }
        .onAppear(perform: load)
        .onReceive(NotificationCenter.default.publisher(for: .wikiUpdated)) { _ in load() }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("아직 위키가 없어요", systemImage: "books.vertical")
        } description: {
            Text("메모함에서 정리본을 선택하고 ‘위키에 정리’를 누르면\n토픽별 위키가 만들어집니다.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        List {
            ForEach(wikis) { wiki in
                NavigationLink(value: wiki) {
                    WikiRowView(wiki: wiki, relatedCount: relatedCounts[wiki.id] ?? 0)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
            }
        }
        .listStyle(.sidebar)
    }

    private func load() {
        do {
            wikis = try appState.wikiRepository.fetchAll()
            var counts: [String: Int] = [:]
            for wiki in wikis {
                counts[wiki.id] = (try? appState.wikiRepository.relatedWikiIds(forWiki: wiki.id).count) ?? 0
            }
            relatedCounts = counts
        } catch {
            NSLog("[Campsis] Failed to load wikis: \(error)")
        }
    }
}

/// 위키 리스트 행: 제목·요약·구성 메모 수·관련 위키 수·정리 상태.
struct WikiRowView: View {
    let wiki: Wiki
    var relatedCount: Int = 0
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "book.closed.fill")
                .font(.title3)
                .foregroundStyle(Color.chatAccent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(wiki.title)
                        .font(.title3)
                        .lineLimit(1)
                    statusBadge
                }
                if let summary = wiki.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 10) {
                    Label("\(wiki.memberCount)", systemImage: "note.text")
                    if relatedCount > 0 {
                        Label("\(relatedCount)", systemImage: "link")
                    }
                    Text(wiki.updatedAt.formatted(.dateTime.month().day().hour().minute()))
                        .foregroundStyle(.tertiary)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if isHovered {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.primary.opacity(0.07) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch wiki.markdownStatus {
        case .pending, .processing:
            HStack(spacing: 3) {
                ProgressView().controlSize(.mini)
                Text("정리 중")
            }
            .font(.caption2)
            .foregroundStyle(.orange)
        case .failed:
            Label("실패", systemImage: "exclamationmark.circle")
                .font(.caption2)
                .foregroundStyle(.red)
        case .completed:
            EmptyView()
        }
    }
}
