import SwiftUI

struct MemoriesView: View {
    @Environment(AppState.self) var appState
    @State private var sources: [Source] = []
    @State private var selectedFilter: SourceFilter = .all
    @State private var selectedSource: Source?

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
    }

    private var filterBar: some View {
        HStack {
            Picker("Filter", selection: $selectedFilter) {
                ForEach(SourceFilter.allCases) { filter in
                    Text(filter.label).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Spacer()

            Text("\(sources.count) items")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var sourceList: some View {
        List(sources) { source in
            MemoryRowView(source: source)
                .onTapGesture { selectedSource = source }
        }
        .listStyle(.plain)
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
                .foregroundStyle(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(titleText)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let app = source.application {
                        Text(app)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(source.capturedAt, style: .relative)
                        .font(.caption)
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
