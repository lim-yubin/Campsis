import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    var body: some View {
        TabView {
            ShortcutSettingsView()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
        }
        .frame(width: 450, height: 250)
    }
}

struct ShortcutSettingsView: View {
    var body: some View {
        Form {
            Section("Global Shortcuts") {
                HStack {
                    Text("Remember Current Context")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .rememberContext)
                }

                HStack {
                    Text("Quick Memory")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .quickMemory)
                }
            }

            Section {
                Button("Restore Defaults") {
                    KeyboardShortcuts.reset(.rememberContext, .quickMemory)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
