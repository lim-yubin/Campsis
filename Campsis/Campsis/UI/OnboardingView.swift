import SwiftUI
import Combine

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var step = 0
    @State private var accessGranted = PermissionManager.accessibilityStatus == .granted
    @State private var screenGranted = PermissionManager.screenRecordingStatus == .granted

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 24) {
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            footer
        }
        .padding(32)
        .frame(width: 520, height: 460)
        .onReceive(timer) { _ in
            accessGranted = PermissionManager.accessibilityStatus == .granted
            screenGranted = PermissionManager.screenRecordingStatus == .granted
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: welcomeStep
        case 1: accessibilityStep
        case 2: screenRecordingStep
        default: shortcutsStep
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Campsis에 오신 걸 환영합니다")
                .font(.title.bold())
            Text("화면 어디서나 텍스트·스크린샷·메모를 단축키로 저장하고,\n저장된 기억에게 무엇이든 물어보세요. 모든 데이터는 기기 안에만 저장됩니다.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }

    private var accessibilityStep: some View {
        permissionStep(
            icon: "accessibility",
            title: "접근성 권한",
            description: "선택한 텍스트를 그대로 저장하려면 접근성 권한이 필요합니다.",
            granted: accessGranted,
            request: { PermissionManager.requestAccessibility() },
            openSettings: { PermissionManager.openAccessibilitySettings() }
        )
    }

    private var screenRecordingStep: some View {
        permissionStep(
            icon: "camera.viewfinder",
            title: "화면 녹화 권한",
            description: "텍스트가 없을 때 화면을 캡처해 저장하려면 화면 녹화 권한이 필요합니다.",
            granted: screenGranted,
            request: { PermissionManager.requestScreenRecording() },
            openSettings: { PermissionManager.openScreenRecordingSettings() }
        )
    }

    private func permissionStep(icon: String, title: String, description: String,
                                granted: Bool, request: @escaping () -> Void,
                                openSettings: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text(title)
                .font(.title2.bold())
            Text(description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if granted {
                Label("권한이 허용되었습니다", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.headline)
            } else {
                HStack(spacing: 10) {
                    Button("권한 요청") { request() }
                        .buttonStyle(.borderedProminent)
                    Button("시스템 설정 열기") { openSettings() }
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    private var shortcutsStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "keyboard")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("단축키 안내")
                .font(.title2.bold())
            Text("기본 단축키로 언제든 기억을 저장하고 열 수 있습니다.\n단축키는 설정에서 바꿀 수 있습니다.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                shortcutRow("⌥ Space", "현재 컨텍스트 기억")
                shortcutRow("⌥ ⇧ Space", "빠른 메모")
                shortcutRow("⌥ ⇧ M", "기억 창 열기")
            }
            .padding(16)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func shortcutRow(_ keys: String, _ label: String) -> some View {
        HStack {
            Text(keys)
                .font(.system(.body, design: .monospaced).bold())
                .frame(width: 120, alignment: .leading)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var footer: some View {
        HStack {
            if step > 0 {
                Button("이전") { step -= 1 }
                    .buttonStyle(.bordered)
            }
            Spacer()
            stepIndicator
            Spacer()
            Button(step == totalSteps - 1 ? "완료" : "다음") {
                if step == totalSteps - 1 {
                    finish()
                } else {
                    step += 1
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .frame(width: 7, height: 7)
                    .foregroundStyle(index == step ? Color.accentColor : Color.secondary.opacity(0.3))
            }
        }
    }

    private func finish() {
        hasCompletedOnboarding = true
        isPresented = false
    }
}
