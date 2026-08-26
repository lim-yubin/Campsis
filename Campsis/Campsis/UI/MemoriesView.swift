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

        let filtered: [Source]
        if let date = selectedDate {
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            filtered = sources.filter { $0.capturedAt >= dayStart && $0.capturedAt < dayEnd }
        } else {
            filtered = sources
        }

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

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            Divider()
            sourceList
        }
        .onAppear { loadSources() }
        .onChange(of: selectedFilter) { _, _ in loadSources() }
        .sheet(item: $selectedSource) { source in
            SourceDetailView(source: source)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf, .plainText, .png, .jpeg],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            Picker("Filter", selection: $selectedFilter) {
                ForEach(SourceFilter.allCases) { filter in
                    Text(filter.label).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Spacer()

            if let status = importStatus {
                Text(status)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Text("\(filteredCount) items")
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
                .foregroundStyle(selectedDate != nil ? .blue : .secondary)
            }
            .buttonStyle(.plain)
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
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var calendarPopover: some View {
        VStack(spacing: 12) {
            DatePicker(
                "Select Date",
                selection: $calendarDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .focusable(false)
            .scaleEffect(1.4)
            .frame(width: 280, height: 260)
            .onChange(of: calendarDate) { _, newDate in
                selectedDate = newDate
            }

            if selectedDate != nil {
                Button("Reset") {
                    selectedDate = nil
                    showCalendar = false
                }
                .font(.body)
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
            }
        }
        .padding(8)
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
                    importStatus = "\(count) file(s) imported"
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

        if groups.isEmpty && selectedDate != nil {
            ContentUnavailableView(
                "No memories",
                systemImage: "calendar.badge.exclamationmark",
                description: Text("선택한 날짜에 저장된 기억이 없습니다.")
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
                                .onTapGesture { selectedSource = source }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        sourceToDelete = source
                                    } label: {
                                        Label("Delete", systemImage: "trash")
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
        case .all: return "All"
        case .text: return "Text"
        case .screenshot: return "Screenshot"
        case .note: return "Note"
        case .voice: return "Voice"
        case .file: return "File"
        }
    }
}

struct MemoryRowView: View {
    let source: Source

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

            Spacer()

            statusBadge
        }
        .padding(.vertical, 4)
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
        case .selectedText: return .blue
        case .screenshot: return .purple
        case .note: return .orange
        case .voice: return .green
        case .file: return .gray
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
        case .processing:
            ProgressView()
                .scaleEffect(0.6)
        case .completed:
            EmptyView()
        case .failed:
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(.red)
                .font(.caption)
        }
    }
}
