import AppKit
import SwiftUI

final class CapturePopupController {
    static let shared = CapturePopupController()

    private var panel: NSPanel?
    private var toastPanel: NSPanel?

    private init() {
        NotificationCenter.default.addObserver(
            forName: .captureSaved, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.showSavedToast()
            }
        }
    }

    func show(payload: CapturePayload, repository: SourceRepository, processingQueue: ProcessingQueue?) {
        close()

        let view = CapturePopupView(payload: payload, repository: repository, processingQueue: processingQueue) { [weak self] in
            self?.close()
        }

        let panel = makeFloatingPanel(
            view,
            defaultSize: NSSize(width: 560, height: 460),
            minSize: NSSize(width: 480, height: 360)
        )
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    func showQuickNote(repository: SourceRepository, processingQueue: ProcessingQueue?) {
        close()

        let view = QuickNotePopupView(repository: repository, processingQueue: processingQueue) { [weak self] in
            self?.close()
        }

        let panel = makeFloatingPanel(
            view,
            defaultSize: NSSize(width: 520, height: 380),
            minSize: NSSize(width: 460, height: 320)
        )
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    /// 공통 플로팅 패널 생성. 리사이즈 가능(.resizable) + 최소 크기 제약 + 활성 스크린 중앙 배치.
    private func makeFloatingPanel(_ content: some View,
                                   defaultSize: NSSize,
                                   minSize: NSSize) -> NSPanel {
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(origin: .zero, size: defaultSize)

        let panel = NSPanel(
            contentRect: hostingView.frame,
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.contentMinSize = minSize
        panel.contentView = hostingView
        centerOnActiveScreen(panel)
        return panel
    }

    /// 마우스가 위치한 스크린의 visibleFrame 중앙으로 패널을 이동한다.
    private func centerOnActiveScreen(_ panel: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main
        guard let screen else { return }
        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let x = screenFrame.midX - panelSize.width / 2
        let y = screenFrame.midY - panelSize.height / 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func close() {
        panel?.close()
        panel = nil
    }

    func showSavedToast() {
        toastPanel?.close()

        let toast = HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("기억함")
                .font(.headline)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

        let hostingView = NSHostingView(rootView: toast)
        hostingView.frame = NSRect(x: 0, y: 0, width: 160, height: 56)

        let panel = NSPanel(
            contentRect: hostingView.frame,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.contentView = hostingView

        centerOnActiveScreen(panel)

        panel.orderFrontRegardless()
        self.toastPanel = panel

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.toastPanel?.close()
            self?.toastPanel = nil
        }
    }
}
