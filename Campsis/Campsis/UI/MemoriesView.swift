import SwiftUI
import UniformTypeIdentifiers

struct MemoriesView: View {
    /// 사이드바가 소유하는 필터·검색어. 필터별로 뷰가 .id로 재생성된다.
    let filter: LibraryItem
    @Binding var searchText: String

    @Environment(AppState.self) var appState
    @State private var sources: [Source] = []
    @State private var selectedSource: Source?
    @State private var showFileImporter = false
    @State private var importStatus: String?
    @State private var collapsedDates: Set<String> = []
    @State private var selectedDate: Date? = nil
    @State private var showCalendar = false
    @State private var calendarDate: Date = Date()

    // Phase 6: 의미검색 결과(소스 ID) + 디바운스 태스크
    @State private var semanticMatchIDs: Set<String> = []
    @State private var searchDebounce: Task<Void, Never>?

    // Phase 8.9: 사이드바 검색 결과에 위키 페이지 포함(상단 노출 → 위키 상세로 이동)
    @State private var wikiMatches: [WikiSearchResult] = []

    // Phase 8.2: 소속 위키 배지 맵(소스 id → 위키 제목들) + 위키 주입 필터
    @State private var wikiMembership: [String: [String]] = [:]
    @State private var wikiCount = 0
    @State private var wikiFilter: WikiFilter = .all

    // 콘텐츠 유형 필터(사이드바에서 콘텐츠 필터바로 이동).
    @State private var typeFilter: MemoryTypeFilter = .all

    // Phase 8.3: 승격(위키에 정리) 선택 모드
    @State private var isSelecting = false
    @State private var selectedForPromotion: Set<String> = []
    @State private var showPromotionSheet = false

    enum WikiFilter: String, CaseIterable, Identifiable {
        case all, unlinked, linked
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: return "전체"
            case .unlinked: return "위키 미주입"
            case .linked: return "위키 주입됨"
            }
        }
    }

    private var filteredCount: Int {
        groupedSources.reduce(0) { $0 + $1.sources.count }
    }

    private var groupedSources: [(key: String, label: String, sources: [Source])] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let labelFormatter = DateFormatter()
        labelFormatter.locale = Locale(identifier: "ko_KR")
        labelFormatter.dateFormat = "yyyy년 M월 d일"

        let base: [Source]
        if let date = selectedDate {
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            base = sources.filter { $0.capturedAt >= dayStart && $0.capturedAt < dayEnd }
        } else {
            base = sources
        }

        let filtered = base.filter { matchesSearch($0) && matchesWikiFilter($0) }

        let grouped = Dictionary(grouping: filtered) { source in
            formatter.string(from: source.capturedAt)
        }

        return grouped.keys.sorted(by: >).map { key in
            let date = formatter.date(from: key) ?? Date()
            let label = labelFormatter.string(from: date)
            let items = grouped[key]!.sorted { $0.capturedAt > $1.capturedAt }
            return (key: key, label: label, sources: items)
        }
    }

    private func matchesSearch(_ source: Source) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return true }
        let fields = [source.content, source.summary, source.ocrText,
                      source.transcript, source.userNote, source.windowTitle, source.application]
        // 정확 일치(텍스트 포함) 우선, 없으면 의미검색 결과 포함 여부로 판정.
        if fields.contains(where: { $0?.lowercased().contains(query) == true }) { return true }
        return semanticMatchIDs.contains(source.id)
    }

    /// 위키 주입 여부 필터.
    private func matchesWikiFilter(_ source: Source) -> Bool {
        switch wikiFilter {
        case .all: return true
        case .unlinked: return wikiMembership[source.id] == nil
        case .linked: return wikiMembership[source.id] != nil
        }
    }

    /// 선택 가능한(=아직 위키 미주입) 현재 표시 중 메모 여부.
    private func isSelectable(_ source: Source) -> Bool {
        wikiMembership[source.id] == nil
    }

    /// 현재 필터/검색에 노출되는 승격 가능(미주입) 메모 id 목록. 전체 선택 대상.
    private var selectableSourceIDs: [String] {
        groupedSources.flatMap { $0.sources }.filter { isSelectable($0) }.map { $0.id }
    }

    /// 선택된 id에 해당하는 Source 객체(승격 시트 전달용).
    private var selectedSources: [Source] {
        sources.filter { selectedForPromotion.contains($0.id) }
    }

    private func toggleSelection(_ source: Source) {
        if selectedForPromotion.contains(source.id) {
            selectedForPromotion.remove(source.id)
        } else {
            selectedForPromotion.insert(source.id)
        }
    }

    private func enterSelectionMode() {
        // 미주입만 승격 대상이므로 자연스럽게 미주입 필터로 전환.
        if wikiCount > 0 { wikiFilter = .unlinked }
        selectedForPromotion = []
        isSelecting = true
    }

    private func exitSelectionMode() {
        isSelecting = false
        selectedForPromotion = []
    }

    /// 사이드바 검색어를 의미검색으로 승격. 디바운스 후 메모(임베딩 유사도)와
    /// 위키 페이지(Phase 8.9)를 함께 조회해 결과를 병합한다.
    private func runSemanticSearch(_ rawQuery: String) {
        searchDebounce?.cancel()
        let trimmed = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, let engine = appState.searchEngine else {
            semanticMatchIDs = []
            wikiMatches = []
            return
        }
        searchDebounce = Task {
            try? await Task.sleep(for: .milliseconds(350))
            if Task.isCancelled { return }
            do {
                async let memoResults = engine.search(query: trimmed, topN: 30, minScore: 0.25)
                async let wikiResults = engine.searchWikis(query: trimmed, topN: 5, minScore: 0.3)
                let (memos, wikis) = try await (memoResults, wikiResults)
                if Task.isCancelled { return }
                let ids = Set(memos.map { $0.source.id })
                await MainActor.run {
                    semanticMatchIDs = ids
                    wikiMatches = wikis
                }
            } catch {
                NSLog("[Campsis] Semantic search failed: \(error)")
            }
        }
    }

    /// 현재 검색어로 새 채팅을 시작하도록 브리지.
    private func startChatWithSearch() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        appState.pendingChatPrefill = trimmed
        NotificationCenter.default.post(name: .requestNewChat, object: nil)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                Divider()
                sourceList
                if isSelecting {
                    Divider()
                    selectionActionBar
                }
            }
            .navigationTitle(filter.label)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if isSelecting {
                        Button("취소") { exitSelectionMode() }
                    } else {
                        Button {
                            enterSelectionMode()
                        } label: {
                            Label("위키에 정리", systemImage: "checklist")
                        }
                        .help("메모를 선택해 위키로 정리")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    InspectorToggleButton()
                }
            }
            .navigationDestination(item: $selectedSource) { source in
                SourceDetailView(source: source)
            }
            .onAppear {
                if filter == .today {
                    selectedDate = Calendar.current.startOfDay(for: Date())
                }
                loadSources()
                runSemanticSearch(searchText)
            }
            .onChange(of: searchText) { _, newValue in
                runSemanticSearch(newValue)
            }
            .onChange(of: typeFilter) { _, _ in
                loadSources()
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.pdf, .plainText, .png, .jpeg],
                allowsMultipleSelection: true
            ) { result in
                handleFileImport(result)
            }
            .sheet(isPresented: $showPromotionSheet) {
                WikiPromotionSheet(sources: selectedSources) { didPromote in
                    showPromotionSheet = false
                    if didPromote {
                        exitSelectionMode()
                        loadSources()
                    }
                }
                .environment(appState)
            }
        }
    }

    /// 선택 모드 하단 액션 바: 선택 개수 · 전체 선택/해제 · "위키에 정리".
    private var selectionActionBar: some View {
        let selectable = selectableSourceIDs
        let allSelected = !selectable.isEmpty && selectable.allSatisfy { selectedForPromotion.contains($0) }
        return HStack(spacing: 12) {
            Button(allSelected ? "전체 해제" : "전체 선택") {
                if allSelected {
                    selectedForPromotion.subtract(selectable)
                } else {
                    selectedForPromotion.formUnion(selectable)
                }
            }
            .buttonStyle(.link)
            .disabled(selectable.isEmpty)

            Text("\(selectedForPromotion.count)개 선택됨")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                showPromotionSheet = true
            } label: {
                Label("위키에 정리", systemImage: "sparkles")
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedForPromotion.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(MemoryTypeFilter.allCases) { t in
                    Button {
                        typeFilter = t
                    } label: {
                        Label(t.label, systemImage: t.systemImage)
                    }
                }
            } label: {
                Label(typeFilter.label, systemImage: typeFilter.systemImage)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("표시할 기억 유형")

            if wikiCount > 0 {
                Picker("위키 주입", selection: $wikiFilter) {
                    ForEach(WikiFilter.allCases) { f in
                        Text(f.label).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }

            Spacer()

            if let status = importStatus {
                Text(status)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Text("\(filteredCount)개")
                .font(.body)
                .foregroundStyle(.secondary)

            Button {
                showCalendar.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.body)
                    if let date = selectedDate {
                        Text(date.formatted(.dateTime.month().day()))
                            .font(.body)
                    }
                }
                .foregroundStyle(selectedDate != nil ? Color.chatAccent : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("날짜 필터")
            .popover(isPresented: $showCalendar, arrowEdge: .bottom) {
                calendarPopover
            }

            Button {
                showFileImporter = true
            } label: {
                Image(systemName: "plus.circle")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("파일 가져오기")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var calendarPopover: some View {
        VStack(spacing: 12) {
            DatePicker(
                "날짜 선택",
                selection: $calendarDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .frame(width: 320)
            .onChange(of: calendarDate) { _, newDate in
                selectedDate = newDate
            }

            if selectedDate != nil {
                Button("초기화") {
                    selectedDate = nil
                    showCalendar = false
                }
                .font(.body)
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
            }
        }
        .padding(16)
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            let importer = FileImporter(
                repository: appState.sourceRepository,
                processingQueue: appState.processingQueueRef as? ProcessingQueue
            )
            Task {
                var count = 0
                for url in urls {
                    do {
                        _ = try await importer.importFile(at: url)
                        count += 1
                    } catch {
                        NSLog("[Campsis] File import error: \(error)")
                    }
                }
                await MainActor.run {
                    importStatus = "파일 \(count)개 가져옴"
                    loadSources()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        importStatus = nil
                    }
                }
            }
        case .failure(let error):
            NSLog("[Campsis] File picker error: \(error)")
        }
    }

    @State private var sourceToDelete: Source?

    /// 기억이 하나도 없을 때(신규 사용자) 저장 방법을 안내하는 빈 상태.
    private var emptyLibraryState: some View {
        ContentUnavailableView {
            Label(emptyTitle, systemImage: "tray")
        } description: {
            Text(emptyDescription)
        } actions: {
            if typeFilter == .all {
                Button {
                    NotificationCenter.default.post(name: .triggerQuickMemory, object: nil)
                } label: {
                    Label("빠른 메모 작성", systemImage: "square.and.pencil")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyTitle: String {
        if typeFilter == .all { return "아직 저장된 기억이 없어요" }
        return "아직 \(typeFilter.label) 기억이 없어요"
    }

    private var emptyDescription: String {
        if typeFilter == .all {
            return "화면 어디서나 ⌥Space로 텍스트·스크린샷을,\n⌥⇧Space로 빠른 메모를 저장할 수 있어요."
        }
        return "다른 유형의 기억은 상단 유형 필터에서 확인할 수 있어요."
    }

    /// 필터·검색·날짜로 결과가 비었을 때의 설명 문구.
    private var noResultsDescription: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "검색 결과가 없습니다."
        }
        if selectedDate != nil {
            return "선택한 날짜에 저장된 기억이 없습니다."
        }
        if typeFilter != .all {
            return "‘\(typeFilter.label)’ 유형에 해당하는 기억이 없어요."
        }
        if wikiFilter != .all {
            return "이 조건에 맞는 기억이 없어요."
        }
        return "표시할 기억이 없습니다."
    }

    @ViewBuilder
    private var sourceList: some View {
        let groups = groupedSources
        let searching = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if sources.isEmpty {
            // 이 라이브러리에 기억이 하나도 없음(신규 사용자 포함) → 저장 방법 안내.
            emptyLibraryState
        } else if groups.isEmpty && wikiMatches.isEmpty {
            // 기억은 있으나 검색·날짜·위키 필터로 전부 걸러진 경우.
            ContentUnavailableView(
                "기억 없음",
                systemImage: "magnifyingglass",
                description: Text(noResultsDescription)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                if searching {
                    searchChatBridge
                        .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                        .listRowSeparator(.hidden)
                }
                if searching && !wikiMatches.isEmpty {
                    wikiMatchesBlock
                }
                ForEach(groups, id: \.key) { group in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { !collapsedDates.contains(group.key) },
                            set: { expanded in
                                if expanded {
                                    collapsedDates.remove(group.key)
                                } else {
                                    collapsedDates.insert(group.key)
                                }
                            }
                        )
                    ) {
                        ForEach(group.sources) { source in
                            MemoryRowView(source: source,
                                          isSelected: selectedSource?.id == source.id,
                                          wikiTitles: wikiMembership[source.id] ?? [],
                                          isSelecting: isSelecting,
                                          isChecked: selectedForPromotion.contains(source.id),
                                          isSelectable: isSelectable(source))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if isSelecting {
                                        if isSelectable(source) { toggleSelection(source) }
                                    } else {
                                        selectedSource = source
                                    }
                                }
                                .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                                .contextMenu {
                                    Button(role: .destructive) {
                                        sourceToDelete = source
                                    } label: {
                                        Label("삭제", systemImage: "trash")
                                    }
                                }
                        }
                    } label: {
                        HStack {
                            Text(group.label)
                                .font(.body.weight(.medium))
                            Text("(\(group.sources.count))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .confirmationDialog(
                "이 기억을 삭제하시겠습니까?",
                isPresented: Binding(
                    get: { sourceToDelete != nil },
                    set: { if !$0 { sourceToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("삭제", role: .destructive) {
                    if let source = sourceToDelete {
                        deleteSource(source)
                    }
                }
                Button("취소", role: .cancel) {
                    sourceToDelete = nil
                }
            } message: {
                Text("삭제된 기억은 복구할 수 없습니다.")
            }
        }
    }

    /// Phase 8.9: 검색 결과 상단의 위키 매칭 블록(위키 우선 노출). 탭 → 나의 위키 상세로 이동.
    @ViewBuilder
    private var wikiMatchesBlock: some View {
        Text("위키")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 2, trailing: 8))
            .listRowSeparator(.hidden)
        ForEach(wikiMatches, id: \.wiki.id) { result in
            wikiSearchRow(result.wiki)
                .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                .listRowSeparator(.hidden)
        }
    }

    private func wikiSearchRow(_ wiki: Wiki) -> some View {
        Button {
            appState.pendingWikiId = wiki.id
            NotificationCenter.default.post(name: .openWiki, object: nil)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "book.closed.fill")
                    .font(.callout)
                    .foregroundStyle(Color.chatAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(wiki.title)
                        .font(.body)
                        .lineLimit(1)
                    if let summary = wiki.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Text("메모 \(wiki.memberCount)개")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.chatAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 검색 결과 상단의 "이 검색어로 채팅하기" 브리지 버튼.
    private var searchChatBridge: some View {
        Button {
            startChatWithSearch()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.text.bubble.right")
                    .foregroundStyle(Color.chatAccent)
                Text("‘\(searchText.trimmingCharacters(in: .whitespacesAndNewlines))’ 로 채팅하기")
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.chatAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func deleteSource(_ source: Source) {
        do {
            // 삭제 전 소속 위키를 확보(삭제 시 note_wiki_link는 cascade로 사라짐).
            let affectedWikis = (try? appState.wikiRepository.wikiIds(forSource: source.id)) ?? []
            try appState.sourceRepository.delete(source)
            sources.removeAll { $0.id == source.id }
            // 위키 member_count 캐시 정합성 복구 + 위키 뷰 새로고침.
            if !affectedWikis.isEmpty {
                try? appState.wikiRepository.refreshMemberCounts(forWikis: affectedWikis)
                NotificationCenter.default.post(name: .wikiUpdated, object: nil)
            }
            loadWikiMembership()
        } catch {
            NSLog("[Campsis] Failed to delete source: \(error)")
        }
    }

    private func loadSources() {
        // 스코프(전체/오늘)는 selectedDate로 걸러지므로 여기선 유형만 반영한다.
        do {
            if let type = typeFilter.sourceType {
                sources = try appState.sourceRepository.fetchAll(type: type)
            } else {
                sources = try appState.sourceRepository.fetchAll()
            }
        } catch {
            NSLog("[Campsis] Failed to load sources: \(error)")
        }
        loadWikiMembership()
    }

    /// 소속 위키 배지 맵과 위키 개수를 갱신한다(메모함 진입/갱신 시).
    private func loadWikiMembership() {
        do {
            wikiMembership = try appState.wikiRepository.membershipTitles()
            wikiCount = try appState.wikiRepository.count()
            if wikiCount == 0 { wikiFilter = .all }
        } catch {
            NSLog("[Campsis] Failed to load wiki membership: \(error)")
        }
    }
}

/// 사이드바 "기억" 섹션의 스코프 필터. 타입 필터는 MemoryTypeFilter로 분리됨.
enum LibraryItem: String, CaseIterable, Identifiable, Hashable {
    case all, today

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "전체 기억"
        case .today: return "오늘"
        }
    }

    var systemImage: String {
        switch self {
        case .all: return "square.stack"
        case .today: return "clock"
        }
    }
}

/// 메모함 콘텐츠 필터바의 "유형" 필터. SourceType으로 매핑되며 all이면 전체.
enum MemoryTypeFilter: String, CaseIterable, Identifiable, Hashable {
    case all, text, screenshot, note, voice, file

    var id: String { rawValue }

    /// 대응하는 SourceType. all이면 nil(전체).
    var sourceType: SourceType? {
        switch self {
        case .all: return nil
        case .text: return .selectedText
        case .screenshot: return .screenshot
        case .note: return .note
        case .voice: return .voice
        case .file: return .file
        }
    }

    var label: String {
        switch self {
        case .all: return "전체 유형"
        case .text: return "텍스트"
        case .screenshot: return "스크린샷"
        case .note: return "메모"
        case .voice: return "음성"
        case .file: return "파일"
        }
    }

    var systemImage: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .text: return "text.quote"
        case .screenshot: return "camera"
        case .note: return "note.text"
        case .voice: return "waveform"
        case .file: return "doc"
        }
    }
}

struct MemoryRowView: View {
    let source: Source
    var isSelected: Bool = false
    /// 이 메모가 속한 위키 제목들(Phase 8.2 소속 위키 배지). 비어 있으면 미주입.
    var wikiTitles: [String] = []
    // Phase 8.3: 승격 선택 모드
    var isSelecting: Bool = false
    var isChecked: Bool = false
    var isSelectable: Bool = true
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            if isSelecting {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isChecked ? Color.chatAccent : (isSelectable ? Color.secondary : Color.secondary.opacity(0.3)))
                    .accessibilityLabel(isChecked ? "선택됨" : "선택 안 됨")
            }
            leadingVisual

            VStack(alignment: .leading, spacing: 3) {
                Text(source.displayTitle)
                    .font(.title3)
                    .lineLimit(1)

                if let snippet {
                    Text(snippet)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !wikiTitles.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(wikiTitles.prefix(3), id: \.self) { title in
                            HStack(spacing: 3) {
                                Image(systemName: "book.closed.fill")
                                    .font(.system(size: 8))
                                Text(title)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 1)
                            .padding(.horizontal, 6)
                            .background(Color.chatAccent.opacity(0.16), in: Capsule())
                            .foregroundStyle(Color.chatAccent)
                        }
                        if wikiTitles.count > 3 {
                            Text("+\(wikiTitles.count - 3)")
                                .font(.caption2)
                                .foregroundStyle(Color.chatAccent)
                        }
                    }
                }

                HStack(spacing: 6) {
                    ForEach(topicChips, id: \.self) { topic in
                        Text(topic)
                            .font(.caption2)
                            .padding(.vertical, 1)
                            .padding(.horizontal, 6)
                            .background(Color.secondary.opacity(0.14), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                    if let app = source.application {
                        Text(app)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(source.capturedAt.formatted(.dateTime.month().day().hour().minute()))
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 8)

            if isHovered {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            statusBadge
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(rowBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .opacity(isSelecting && !isSelectable ? 0.45 : 1)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }

    /// 좌측 시각 요소: 스크린샷/이미지는 썸네일, 그 외는 타입 아이콘.
    @ViewBuilder
    private var leadingVisual: some View {
        if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        } else {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 28)
        }
    }

    private var rowBackground: Color {
        if isSelected { return Color.accentColor.opacity(0.12) }
        if isHovered { return Color.primary.opacity(0.07) }
        return Color.clear
    }

    /// 제목 아래 1줄 요약 스니펫. summary 우선, 없으면 본문 앞부분.
    private var snippet: String? {
        let raw = source.summary ?? source.content ?? source.ocrText ?? source.transcript
        guard let raw else { return nil }
        let cleaned = raw
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned != source.displayTitle else { return nil }
        return cleaned
    }

    /// 주제 태그 미니칩(최대 3개).
    private var topicChips: [String] {
        guard let json = source.topics,
              let data = json.data(using: .utf8),
              let topics = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Array(topics.prefix(3))
    }

    /// 스크린샷/이미지 파일용 썸네일.
    private var thumbnail: NSImage? {
        if source.type == .screenshot, let path = source.screenshotPath {
            return NSImage(contentsOf: AppPaths.absoluteURL(from: path))
        }
        if source.type == .file, let path = source.filePath {
            let ext = (path as NSString).pathExtension.lowercased()
            if ["png", "jpg", "jpeg", "gif", "heic", "webp", "tiff"].contains(ext) {
                return NSImage(contentsOf: AppPaths.absoluteURL(from: path))
            }
        }
        return nil
    }

    private var iconName: String {
        switch source.type {
        case .selectedText: return "text.quote"
        case .screenshot: return "camera"
        case .note: return "note.text"
        case .voice: return "waveform"
        case .file: return "doc"
        }
    }

    private var iconColor: Color {
        switch source.type {
        case .selectedText: return .sourceText
        case .screenshot: return .sourceScreenshot
        case .note: return .sourceNote
        case .voice: return .sourceVoice
        case .file: return .sourceFile
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch source.processingStatus {
        case .pending:
            Image(systemName: "clock")
                .foregroundStyle(.orange)
                .font(.caption)
                .accessibilityLabel("처리 대기 중")
        case .processing:
            ProgressView()
                .scaleEffect(0.6)
                .accessibilityLabel("처리 중")
        case .completed:
            EmptyView()
        case .failed:
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(.red)
                .font(.caption)
                .accessibilityLabel("처리 실패")
        }
    }
}
