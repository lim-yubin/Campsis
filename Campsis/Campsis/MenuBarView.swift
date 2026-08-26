import SwiftUI

struct MenuBarView: View {
    var body: some View {
        Button("Quick Memory") {
            // Phase 4
        }
        .keyboardShortcut("m", modifiers: [.option, .shift])

        Divider()

        Button("Open Memory") {
            // Phase 3: Search UI
        }

        Divider()

        SettingsLink {
            Text("Settings…")
        }

        Button("Quit Campsis") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
