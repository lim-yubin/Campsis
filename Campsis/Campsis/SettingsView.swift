import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("일반", systemImage: "gear") }
            ShortcutSettingsView()
                .tabItem { Label("단축키", systemImage: "keyboard") }
        }
        .frame(width: 450, height: 280)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("showDockIcon") private var showDockIcon = true

    var body: some View {
        Form {
            Section("모양") {
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
            Section("전역 단축키") {
                HStack {
                    Text("현재 컨텍스트 기억")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .rememberContext)
                }

                HStack {
                    Text("빠른 메모")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .quickMemory)
                }

                HStack {
                    Text("메모리 열기")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .openMemory)
                }
            }

            Section {
                Button("기본값 복원") {
                    KeyboardShortcuts.reset(.rememberContext, .quickMemory, .openMemory)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
