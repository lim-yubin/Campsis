import AppKit
import SwiftUI

final class CapturePopupController {
    static let shared = CapturePopupController()

    private var panel: NSPanel?

    func show(payload: CapturePayload, repository: SourceRepository) {
        close()

        let view = CapturePopupView(payload: payload, repository: repository) { [weak self] in
            self?.close()
        }

        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 420, height: 320)

        let panel = NSPanel(
            contentRect: hostingView.frame,
            styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.contentView = hostingView

        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main
        if let screen {
            let screenFrame = screen.visibleFrame
            let panelSize = panel.frame.size
            let x = screenFrame.midX - panelSize.width / 2
            let y = screenFrame.midY - panelSize.height / 2
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.makeKeyAndOrderFront(nil)

        self.panel = panel
    }

    func close() {
        panel?.close()
        panel = nil
    }
}
