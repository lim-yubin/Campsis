import AppKit

enum CapturePayload: Sendable {
    case text(CapturedText)
    case screenshot(CapturedScreenshot)
}

struct CapturedText: Sendable {
    let content: String
    let application: String?
    let windowTitle: String?
    let url: String?
}

struct CapturedScreenshot: Sendable {
    let image: NSImage
    let savedPath: String
    let application: String?
    let windowTitle: String?
    let url: String?
}
