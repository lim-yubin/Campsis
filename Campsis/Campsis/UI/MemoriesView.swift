import SwiftUI
import UniformTypeIdentifiers

struct MemoriesView: View {
    @Environment(AppState.self) var appState
    @State private var sources: [Source] = []
    @State private var selectedFilter: SourceFilter = .all
    @State private var selectedSource: Source?
    @State private var showFileImporter = false
    @State private var importStatus: String?
    @State private var collapsedDates: Set<String> = []
    @State private var selectedDate: Date? = nil
    @State private var showCalendar = false
    @State private var calendarDate: Date = Date()
    @State private var searchText = ""

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

        let filtered = base.filter { matchesSearch($0) }

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
        return fields.contains { $0?.lowercased().contains(query) == true }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                filterBar
                Divider()
                sourceList
            }
            .navigationTitle("메모리")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    InspectorToggleButton()
                }
            }
            .navigationDestination(item: $selectedSource) { source in
                SourceDetailView(source: source)
            }
            .onAppear { loadSources() }
            .onChange(of: selectedFilter) { _, _ in loadSources() }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.pdf, .plainText, .png, .jpeg],
                allowsMultipleSelection: true
            ) { result in
                handleFileImport(result)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("기억 검색...", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("검색어 지우기")
            }
        }
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            // 세그먼트(6칸) 대신 컴팩트한 드롭다운을 써서 필터바의 최소 폭을 낮춘다.
            // → 분할선 드래그 시에도 상세 컬럼이 320까지 줄어들 수 있게 함.
            Picker("Filter", selection: $selectedFilter) {
                ForEach(SourceFilter.allCases) { filter in
                    Text(filter.label).tag(filter)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()

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

    @ViewBuilder
    private var sourceList: some View {
        let groups = groupedSources

        if groups.isEmpty && (selectedDate != nil || !searchText.isEmpty) {
            ContentUnavailableView(
                "기억 없음",
                systemImage: "magnifyingglass",
                description: Text(searchText.isEmpty ? "선택한 날짜에 저장된 기억이 없습니다." : "검색 결과가 없습니다.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
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
                            MemoryRowView(source: source)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedSource = source }
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

    private func deleteSource(_ source: Source) {
        do {
            try appState.sourceRepository.delete(source)
            sources.removeAll { $0.id == source.id }
        } catch {
            NSLog("[Campsis] Failed to delete source: \(error)")
        }
    }

    private func loadSources() {
        do {
            switch selectedFilter {
            case .all:
                sources = try appState.sourceRepository.fetchAll()
            case .text:
                sources = try appState.sourceRepository.fetchAll(type: .selectedText)
            case .screenshot:
                sources = try appState.sourceRepository.fetchAll(type: .screenshot)
            case .note:
                sources = try appState.sourceRepository.fetchAll(type: .note)
            case .voice:
                sources = try appState.sourceRepository.fetchAll(type: .voice)
            case .file:
                sources = try appState.sourceRepository.fetchAll(type: .file)
            }
        } catch {
            NSLog("[Campsis] Failed to load sources: \(error)")
        }
    }
}

enum SourceFilter: String, CaseIterable, Identifiable {
    case all, text, screenshot, note, voice, file

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "전체"
        case .text: return "텍스트"
        case .screenshot: return "스크린샷"
        case .note: return "메모"
        case .voice: return "음성"
        case .file: return "파일"
        }
    }
}

struct MemoryRowView: View {
    let source: Source
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(titleText)
                    .font(.title3)
                    .lineLimit(1)

                HStack(spacing: 8) {
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
                .fill(isHovered ? Color.primary.opacity(0.07) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
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

    private var titleText: String {
        if let content = source.content, !content.isEmpty {
            return String(content.prefix(80))
        }
        if let summary = source.summary, !summary.isEmpty {
            return summary
        }
        if let title = source.windowTitle, !title.isEmpty {
            return title
        }
        return source.type.rawValue.capitalized
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
