import SwiftUI

/// "위키에 정리" 승격 시트 — 라우팅 미리보기 (Phase 8.4).
///
/// 선택한 메모를 기존 위키에 매칭(임베딩+태그, OW3)하거나 새 위키를 제안하고,
/// 사용자가 목적지를 확인·수정한다. 실제 승격 실행(링크+백링크)과 재합성은
/// 8.5·8.6에서 이 화면의 "정리 실행"에 연결된다.
struct WikiPromotionSheet: View {
    let sources: [Source]
    /// 닫힘 콜백. 승격이 실제로 수행됐으면 `true`(호출부가 목록을 새로고침).
    let onClose: (Bool) -> Void

    @Environment(AppState.self) private var appState

    @State private var isComputing = true
    @State private var isExecuting = false
    @State private var suggestions: [WikiRoutingSuggestion] = []
    /// sourceId → 선택된 목적지 키 집합. 목적지 키: "wiki:<id>" 또는 "new:<slug>".
    @State private var assignment: [String: Set<String>] = [:]
    /// 새 위키 목적지 키 → 편집 가능한 제목.
    @State private var newTitles: [String: String] = [:]

    private static let newPrefix = "new:"
    private static let wikiPrefix = "wiki:"

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if isComputing {
                computingView
            } else {
                summaryBar
                Divider()
                memoList
            }
            Divider()
            footer
        }
        .frame(width: 520, height: 600)
        .task { await computeRouting() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(Color.chatAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text("위키에 정리")
                    .font(.title3.weight(.semibold))
                Text("선택한 메모 \(sources.count)개를 이렇게 정리할게요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
    }

    private var computingView: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("어울리는 위키를 찾는 중…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 목적지 요약

    private var summaryBar: some View {
        let groups = destinationGroups()
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(groups, id: \.key) { group in
                    destinationChip(group)
                }
                if unassignedCount > 0 {
                    Label("미분류 \(unassignedCount)", systemImage: "questionmark.circle")
                        .font(.caption)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.orange.opacity(0.15), in: Capsule())
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func destinationChip(_ group: DestinationGroup) -> some View {
        HStack(spacing: 4) {
            Image(systemName: group.isNew ? "plus.circle.fill" : "book.closed.fill")
                .font(.system(size: 9))
            if group.isNew {
                TextField("토픽", text: newTitleBinding(group.key))
                    .textFieldStyle(.plain)
                    .frame(width: 72)
                    .font(.caption)
            } else {
                Text(group.title).font(.caption)
            }
            Text("\(group.count)")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 5)
                .background(Color.primary.opacity(0.1), in: Capsule())
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background((group.isNew ? Color.green : Color.chatAccent).opacity(0.15), in: Capsule())
        .foregroundStyle(group.isNew ? Color.green : Color.chatAccent)
    }

    // MARK: - 메모별 목적지 편집

    private var memoList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(suggestions) { suggestion in
                    memoRow(suggestion)
                }
            }
            .padding(16)
        }
    }

    private func memoRow(_ suggestion: WikiRoutingSuggestion) -> some View {
        let sid = suggestion.source.id
        let selected = assignment[sid] ?? []
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: iconName(for: suggestion.source))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text(suggestion.source.displayTitle)
                    .font(.body)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if selected.isEmpty {
                    Text("제외됨")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    // 기존 위키 후보 칩
                    ForEach(suggestion.candidates) { cand in
                        let key = Self.wikiPrefix + cand.wiki.id
                        chip(title: cand.wiki.title,
                             subtitle: scoreText(cand.score),
                             systemImage: "book.closed.fill",
                             isSelected: selected.contains(key),
                             tint: .chatAccent) {
                            toggle(sid, key)
                        }
                    }
                    // 새 위키 제안 칩
                    let newKey = Self.newPrefix + WikiRouter.slug(suggestion.representativeTopic)
                    chip(title: "새 위키 · \(newTitles[newKey] ?? suggestion.representativeTopic)",
                         subtitle: nil,
                         systemImage: "plus.circle.fill",
                         isSelected: selected.contains(newKey),
                         tint: .green) {
                        if newTitles[newKey] == nil { newTitles[newKey] = suggestion.representativeTopic }
                        toggle(sid, newKey)
                    }
                }
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }

    private func chip(title: String, subtitle: String?, systemImage: String,
                      isSelected: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : systemImage)
                    .font(.system(size: 10))
                Text(title).font(.caption).lineLimit(1)
                if let subtitle {
                    Text(subtitle).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 9)
            .background(isSelected ? tint.opacity(0.18) : Color.primary.opacity(0.06), in: Capsule())
            .foregroundStyle(isSelected ? tint : .secondary)
            .overlay(Capsule().stroke(isSelected ? tint.opacity(0.5) : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 8) {
            Label("메모를 눌러 목적지를 바꿀 수 있어요. 여러 위키에 함께 넣거나 제외할 수도 있습니다.",
                  systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Button("취소") { onClose(false) }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button {
                    execute()
                } label: {
                    if isExecuting {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("정리 실행")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isComputing || isExecuting || assignedCount == 0)
                .help("선택한 메모를 위키에 등록합니다")
            }
        }
        .padding(16)
    }

    // MARK: - 라우팅 계산

    private func computeRouting() async {
        let router = WikiRouter(embeddingRepository: appState.embeddingRepository,
                                wikiRepository: appState.wikiRepository,
                                sourceRepository: appState.sourceRepository)
        let input = sources
        let result: [WikiRoutingSuggestion] = await Task.detached {
            (try? router.route(input)) ?? []
        }.value

        suggestions = result
        assignment = Self.defaultAssignment(result)
        // 새 위키 기본 제목 시드
        for s in result where !s.hasAutoMatch {
            let key = Self.newPrefix + WikiRouter.slug(s.representativeTopic)
            if newTitles[key] == nil { newTitles[key] = s.representativeTopic }
        }
        isComputing = false
    }

    /// 기본 배정: 자동 매칭(≥T_high, N_max) 있으면 그 위키들, 없으면 새 위키.
    private static func defaultAssignment(_ suggestions: [WikiRoutingSuggestion]) -> [String: Set<String>] {
        var map: [String: Set<String>] = [:]
        for s in suggestions {
            if s.hasAutoMatch {
                map[s.source.id] = Set(s.autoDestinations.map { wikiPrefix + $0.wiki.id })
            } else {
                map[s.source.id] = [newPrefix + WikiRouter.slug(s.representativeTopic)]
            }
        }
        return map
    }

    // MARK: - 승격 실행 (8.5)

    private var assignedCount: Int {
        suggestions.filter { !(assignment[$0.source.id] ?? []).isEmpty }.count
    }

    /// sourceId → (wikiId → 매칭 점수). 감사·튜닝용 match_score 전달.
    private var scoreMap: [String: [String: Double]] {
        var map: [String: [String: Double]] = [:]
        for s in suggestions {
            var inner: [String: Double] = [:]
            for c in s.candidates { inner[c.wiki.id] = c.score }
            map[s.source.id] = inner
        }
        return map
    }

    private func buildRequest() -> WikiPromotionRequest {
        // destKey → sourceIds
        var byDest: [String: [String]] = [:]
        for (sid, keys) in assignment {
            for k in keys { byDest[k, default: []].append(sid) }
        }
        let scores = scoreMap
        let destinations: [WikiPromotionRequest.Destination] = byDest.map { key, sourceIds in
            if key.hasPrefix(Self.wikiPrefix) {
                let wikiId = String(key.dropFirst(Self.wikiPrefix.count))
                var s: [String: Double] = [:]
                for sid in sourceIds { if let v = scores[sid]?[wikiId] { s[sid] = v } }
                return .init(existingWikiId: wikiId, newTitle: nil, sourceIds: sourceIds, scores: s)
            } else {
                let title = newTitles[key] ?? String(key.dropFirst(Self.newPrefix.count))
                return .init(existingWikiId: nil, newTitle: title, sourceIds: sourceIds, scores: [:])
            }
        }
        return WikiPromotionRequest(destinations: destinations)
    }

    private func execute() {
        isExecuting = true
        let request = buildRequest()
        let promoter = WikiPromoter(wikiRepository: appState.wikiRepository)
        Task {
            let ok: Bool = await Task.detached {
                do { _ = try promoter.execute(request); return true }
                catch {
                    NSLog("[Campsis] Wiki promotion failed: \(error)")
                    return false
                }
            }.value
            isExecuting = false
            onClose(ok)
        }
    }

    // MARK: - 편집 조작

    private func toggle(_ sid: String, _ key: String) {
        var set = assignment[sid] ?? []
        if set.contains(key) {
            set.remove(key)
        } else {
            // N_max 상한: 초과 선택 시 가장 오래된 것을 밀어내지 않고 그대로 추가 허용하되,
            // 3개까지만 유지(초과분은 무시).
            if set.count >= WikiRouter.nMax { return }
            set.insert(key)
        }
        assignment[sid] = set
    }

    private func newTitleBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { newTitles[key] ?? "" },
            set: { newTitles[key] = $0 }
        )
    }

    // MARK: - 목적지 집계

    private struct DestinationGroup {
        let key: String
        let title: String
        let isNew: Bool
        let count: Int
    }

    private func destinationGroups() -> [DestinationGroup] {
        var counts: [String: Int] = [:]
        for (_, keys) in assignment {
            for k in keys { counts[k, default: 0] += 1 }
        }
        // 기존 위키 제목 조회용 맵
        var wikiTitle: [String: String] = [:]
        for s in suggestions {
            for c in s.candidates { wikiTitle[Self.wikiPrefix + c.wiki.id] = c.wiki.title }
        }
        let existing = counts.keys.filter { $0.hasPrefix(Self.wikiPrefix) }.sorted()
        let news = counts.keys.filter { $0.hasPrefix(Self.newPrefix) }.sorted()
        return (existing + news).map { key in
            let isNew = key.hasPrefix(Self.newPrefix)
            let title = isNew
                ? (newTitles[key] ?? String(key.dropFirst(Self.newPrefix.count)))
                : (wikiTitle[key] ?? "위키")
            return DestinationGroup(key: key, title: title, isNew: isNew, count: counts[key] ?? 0)
        }
    }

    private var unassignedCount: Int {
        suggestions.filter { (assignment[$0.source.id] ?? []).isEmpty }.count
    }

    // MARK: - Helpers

    private func scoreText(_ score: Double) -> String {
        "\(Int((score * 100).rounded()))%"
    }

    private func iconName(for source: Source) -> String {
        switch source.type {
        case .selectedText: return "text.quote"
        case .screenshot: return "camera"
        case .note: return "note.text"
        case .voice: return "waveform"
        case .file: return "doc"
        }
    }
}
