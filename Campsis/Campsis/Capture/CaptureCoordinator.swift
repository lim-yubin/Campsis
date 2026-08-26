import AppKit
import KeyboardShortcuts

@Observable
final class CaptureCoordinator {
    private let repository: SourceRepository
    private var processingQueue: ProcessingQueue?

    init(repository: SourceRepository, processingQueue: ProcessingQueue?) {
        self.repository = repository
        self.processingQueue = processingQueue
        registerShortcuts()
    }

    func updateProcessingQueue(_ queue: ProcessingQueue) {
        self.processingQueue = queue
    }

    private func registerShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .rememberContext) { [weak self] in
            self?.handleRememberContext()
        }
        KeyboardShortcuts.onKeyUp(for: .quickMemory) { [weak self] in
            self?.handleQuickMemory()
        }
    }

    private func handleRememberContext() {
        NSLog("[Campsis] handleRememberContext triggered")
        Task {
            if PermissionManager.accessibilityStatus == .granted {
                if let text = await SelectedTextReader.read() {
                    await showCapturePopup(with: .text(text))
                    return
                }
            } else if PermissionManager.accessibilityStatus == .denied {
                PermissionManager.requestAccessibility()
            }

            if PermissionManager.screenRecordingStatus == .granted {
                if let shot = await ScreenshotCapture.capture() {
                    await showCapturePopup(with: .screenshot(shot))
                    return
                }
            } else {
                PermissionManager.requestScreenRecording()
            }
        }
    }

    private func handleQuickMemory() {
        NSLog("[Campsis] handleQuickMemory triggered")
        Task { @MainActor in
            CapturePopupController.shared.showQuickNote(
                repository: repository,
                processingQueue: processingQueue
            )
        }
    }

    @MainActor
    private func showCapturePopup(with payload: CapturePayload) {
        CapturePopupController.shared.show(payload: payload, repository: repository, processingQueue: processingQueue)
    }
}
