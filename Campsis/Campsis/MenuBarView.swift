import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Quick Memory") {
            // Phase 4
        }
        .keyboardShortcut("m", modifiers: [.option, .shift])

        Divider()

        Button("Open Memory") {
            openMemoryWindow()
        }
        .keyboardShortcut("o", modifiers: [.option])

        Divider()

        SettingsLink {
            Text("Settings…")
        }

        Button("Quit Campsis") {
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
