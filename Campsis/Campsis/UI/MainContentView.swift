import SwiftUI
import UniformTypeIdentifiers

enum NavigationItem: String, CaseIterable, Identifiable {
    case search = "Search"
    case memories = "Memories"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .search: return "magnifyingglass"
        case .memories: return "clock"
        }
    }
}

struct MainContentView: View {
    @Environment(AppState.self) var appState
    @State private var selectedItem: NavigationItem = .search
    @State private var isDragOver = false
    @State private var importMessage: String?

    var body: some View {
        NavigationSplitView {
            List(NavigationItem.allCases, selection: $selectedItem) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } detail: {
            switch selectedItem {
            case .search:
                SearchView()
            case .memories:
                MemoriesView()
            }
        }
        .overlay {
            if isDragOver {
                dropOverlay
            }
        }
        .overlay(alignment: .bottom) {
            if let message = importMessage {
                importBanner(message)
            }
        }
        .onDrop(of: supportedTypes, isTargeted: $isDragOver) { providers in
            handleDrop(providers)
            return true
        }
    }

    private var supportedTypes: [UTType] {
        [.pdf, .plainText, .png, .jpeg, .fileURL]
    }

    private var dropOverlay: some View {
        ZStack {
            Color.accentColor.opacity(0.1)
            VStack(spacing: 8) {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 40))
                Text("Drop to import")
                    .font(.title3)
            }
            .foregroundStyle(.tint)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
    }

    private func importBanner(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.bottom, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { importMessage = nil }
                }
            }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                guard let data = data as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }

                let importer = FileImporter(
                    repository: appState.sourceRepository,
                    processingQueue: appState.processingQueueRef as? ProcessingQueue
                )

                Task {
                    do {
                        let source = try await importer.importFile(at: url)
                        await MainActor.run {
                            withAnimation {
                                importMessage = "\(url.lastPathComponent) imported"
                            }
                        }
                    } catch {
                        await MainActor.run {
                            withAnimation {
                                importMessage = "Import failed: \(error.localizedDescription)"
                            }
                        }
                    }
                }
            }
        }
    }
}
