import SwiftUI

/// 나의 위키 — 토픽 허브 리스트 + 상세 (Phase 8.7).
struct WikiListView: View {
    @Environment(AppState.self) private var appState
    @State private var wikis: [Wiki] = []
    @State private var relatedCounts: [String: Int] = [:]
    @State private var path: [Wiki] = []
    // Phase 8.11: 위키 유지보수(Lint) 제안 카드
    @State private var suggestions: [LintSuggestion] = []

    var body: some View {
        NavigationStack(path: $path) {
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
        .onAppear {
            load()
            openPendingWiki()
        }
        .onChange(of: appState.pendingWikiId) { _, _ in openPendingWiki() }
        .onReceive(NotificationCenter.default.publisher(for: .wikiUpdated)) { _ in load() }
    }

    /// 채팅 위키 배지 등에서 지정한 위키를 상세로 push.
    private func openPendingWiki() {
        guard let id = appState.pendingWikiId,
              let wiki = try? appState.wikiRepository.fetch(id: id) else { return }
        appState.pendingWikiId = nil
        path = [wiki]
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
            if !suggestions.isEmpty {
                Section("정리 제안") {
                    ForEach(suggestions) { suggestion in
                        suggestionCard(suggestion)
                            .listRowInsets(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
                            .listRowSeparator(.hidden)
                    }
                }
            }
            Section {
                ForEach(wikis) { wiki in
                    NavigationLink(value: wiki) {
                        WikiRowView(wiki: wiki, relatedCount: relatedCounts[wiki.id] ?? 0)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 3, leading: 8, bottom: 3, trailing: 8))
                }
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Lint 제안 카드 (8.11)

    private func suggestionCard(_ suggestion: LintSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: suggestion.kind == .duplicate ? "arrow.triangle.merge" : "leaf")
                    .foregroundStyle(.orange)
                Text(suggestion.title)
                    .font(.subheadline.weight(.semibold))
            }
            Text(suggestion.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                switch suggestion.kind {
                case .duplicate:
                    Button("합치기") { applyMerge(suggestion) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                case .orphan:
                    Button("삭제", role: .destructive) { deleteOrphan(suggestion) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                Button("무시") { dismiss(suggestion) }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                Spacer(minLength: 0)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private func applyMerge(_ suggestion: LintSuggestion) {
        guard let secondary = suggestion.secondaryWikiId else { return }
        let target = suggestion.primaryWikiId
        do {
            let moved = try appState.wikiRepository.merge(sourceWikiId: secondary, intoWikiId: target)
            load()
            // 병합 내용을 흡수하도록 target 재합성(사람 편집 위키는 엔진이 스킵).
            if let resynth = appState.wikiResynthesizer {
                Task { await resynth.resynthesizeWiki(wikiId: target, addedSourceIds: moved) }
            }
            NotificationCenter.default.post(name: .wikiUpdated, object: nil)
        } catch {
            NSLog("[Campsis] Wiki merge failed: \(error)")
        }
    }

    private func deleteOrphan(_ suggestion: LintSuggestion) {
        guard let wiki = try? appState.wikiRepository.fetch(id: suggestion.primaryWikiId) else { return }
        do {
            try appState.wikiRepository.delete(wiki)
            load()
            NotificationCenter.default.post(name: .wikiUpdated, object: nil)
        } catch {
            NSLog("[Campsis] Orphan wiki delete failed: \(error)")
        }
    }

    private func dismiss(_ suggestion: LintSuggestion) {
        LintDismissStore.dismiss(suggestion.id)
        withAnimation { suggestions.removeAll { $0.id == suggestion.id } }
    }

    private func load() {
        do {
            wikis = try appState.wikiRepository.fetchAll()
            var counts: [String: Int] = [:]
            for wiki in wikis {
                counts[wiki.id] = (try? appState.wikiRepository.relatedWikiIds(forWiki: wiki.id).count) ?? 0
            }
            relatedCounts = counts
            refreshSuggestions()
        } catch {
            NSLog("[Campsis] Failed to load wikis: \(error)")
        }
    }

    /// 위키 메뉴 진입/`.wikiUpdated` 시 로컬 Lint를 돌려 dismiss되지 않은 제안만 노출(OW5 ①②).
    private func refreshSuggestions() {
        let scanned = WikiMaintenance(wikiRepository: appState.wikiRepository).scan()
        suggestions = scanned.filter { !LintDismissStore.isDismissed($0.id) }
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
