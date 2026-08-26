@preconcurrency import AppKit
import ScreenCaptureKit

enum PermissionManager {
    enum Status: Sendable {
        case granted
        case denied
        case notDetermined
    }

    static var accessibilityStatus: Status {
        let trusted = AXIsProcessTrusted()
        return trusted ? .granted : .denied
    }

    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static var screenRecordingStatus: Status {
        if CGPreflightScreenCaptureAccess() {
            return .granted
        }
        return .denied
    }

    static func requestScreenRecording() {
        CGRequestScreenCaptureAccess()
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    static func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
}
