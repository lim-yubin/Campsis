import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("일반", systemImage: "gear") }
            AISettingsView()
                .tabItem { Label("AI", systemImage: "sparkles") }
            ShortcutSettingsView()
                .tabItem { Label("단축키", systemImage: "keyboard") }
        }
        .frame(width: 460, height: 340)
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

struct AISettingsView: View {
    @AppStorage("aiProvider") private var providerRaw = AIProvider.luna.rawValue
    @State private var apiKey: String = ""
    @State private var savedKeyMasked: String?

    var body: some View {
        Form {
            Section("답변 생성 모델") {
                Label(AIProvider.luna.label, systemImage: "cloud")
                Text(AIProvider.luna.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("OpenAI API 키") {
                SecureField("sk-…", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    if let masked = savedKeyMasked {
                        Label("저장됨: \(masked)", systemImage: "checkmark.seal")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text("키가 저장되어 있지 않습니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("저장") { saveKey() }
                        .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                    if savedKeyMasked != nil {
                        Button("삭제", role: .destructive) { clearKey() }
                    }
                }
                Text("키는 이 기기의 Keychain에만 안전하게 저장되며 외부로 전송되지 않습니다. platform.openai.com에서 발급받을 수 있습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            providerRaw = AIProvider.luna.rawValue
            loadKey()
        }
    }

    private func loadKey() {
        if let key = KeychainHelper.openAIKey {
            savedKeyMasked = maskKey(key)
        } else {
            savedKeyMasked = nil
        }
    }

    private func saveKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if KeychainHelper.set(trimmed, for: KeychainHelper.openAIAccount) {
            savedKeyMasked = maskKey(trimmed)
            apiKey = ""
            NotificationCenter.default.post(name: .aiSettingsChanged, object: nil)
        }
    }

    private func clearKey() {
        KeychainHelper.remove(KeychainHelper.openAIAccount)
        savedKeyMasked = nil
        apiKey = ""
        NotificationCenter.default.post(name: .aiSettingsChanged, object: nil)
    }

    private func maskKey(_ key: String) -> String {
        guard key.count > 8 else { return "••••" }
        return String(key.prefix(3)) + "••••" + String(key.suffix(4))
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
                    Text("기억 열기")
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
