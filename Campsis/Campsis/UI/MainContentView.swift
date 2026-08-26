import SwiftUI

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
    }
}
