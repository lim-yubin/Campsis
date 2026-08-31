import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(AppState.self) private var appState

    var body: some View {
        Text(appState.modelStatus.label)

        Divider()

        Button("빠른 메모") {
            NotificationCenter.default.post(name: .triggerQuickMemory, object: nil)
        }

        Divider()

        Button("메모리 열기") {
            openMemoryWindow()
        }

        Divider()

        SettingsLink {
            Text("설정…")
        }

        Button("Campsis 종료") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
        .onReceive(NotificationCenter.default.publisher(for: .openMemoryWindow)) { _ in
            openMemoryWindow()
        }
    }

    private func openMemoryWindow() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}
