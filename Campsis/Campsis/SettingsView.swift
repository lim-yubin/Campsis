import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gear") }
            ShortcutSettingsView()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
        }
        .frame(width: 450, height: 280)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("showDockIcon") private var showDockIcon = true

    var body: some View {
        Form {
            Section("Appearance") {
                Toggle("Dock에 아이콘 표시", isOn: $showDockIcon)
                    .onChange(of: showDockIcon) { _, newValue in
                        NSApp.setActivationPolicy(newValue ? .regular : .accessory)
                    }
                Text("끄면 메뉴바 전용 모드로 동작합니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
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

                HStack {
                    Text("Open Memory")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .openMemory)
                }
            }

            Section {
                Button("Restore Defaults") {
                    KeyboardShortcuts.reset(.rememberContext, .quickMemory, .openMemory)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
