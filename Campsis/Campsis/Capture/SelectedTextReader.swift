import AppKit
import ApplicationServices

enum SelectedTextReader {
    static func read() async -> CapturedText? {
        let frontApp = NSWorkspace.shared.frontmostApplication
        let appName = frontApp?.localizedName
        let pid = frontApp?.processIdentifier ?? 0

        let axApp = AXUIElementCreateApplication(pid)
        let windowTitle = axWindowTitle(axApp)
        let url = await currentURL(for: appName)

        if let text = axSelectedText(axApp), !text.isEmpty {
            return CapturedText(content: text, application: appName, windowTitle: windowTitle, url: url)
        }

        if let text = await clipboardFallback() {
            return CapturedText(content: text, application: appName, windowTitle: windowTitle, url: url)
        }

        return nil
    }

    static func axSelectedText(_ app: AXUIElement) -> String? {
        var focusedElement: AnyObject?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success else {
            return nil
        }
        var selectedText: AnyObject?
        guard AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedText) == .success else {
            return nil
        }
        return selectedText as? String
    }

    static func axWindowTitle(_ app: AXUIElement) -> String? {
        var windowValue: AnyObject?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &windowValue) == .success else {
            return nil
        }
        var title: AnyObject?
        guard AXUIElementCopyAttributeValue(windowValue as! AXUIElement, kAXTitleAttribute as CFString, &title) == .success else {
            return nil
        }
        return title as? String
    }

    private static func clipboardFallback() async -> String? {
        let pasteboard = NSPasteboard.general
        let oldContents = pasteboard.string(forType: .string)
        let oldChangeCount = pasteboard.changeCount

        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true) // 'c'
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        try? await Task.sleep(for: .milliseconds(100))

        let newText: String?
        if pasteboard.changeCount != oldChangeCount {
            newText = pasteboard.string(forType: .string)
            pasteboard.clearContents()
            if let old = oldContents {
                pasteboard.setString(old, forType: .string)
            }
        } else {
            newText = nil
        }

        return newText
    }

    private static func currentURL(for appName: String?) async -> String? {
        guard let name = appName else { return nil }
        switch name {
        case "Google Chrome", "Chromium", "Arc", "Brave Browser":
            return runAppleScript(
                "tell application \"\(name)\" to get URL of active tab of front window"
            )
        case "Safari", "Safari Technology Preview":
            return runAppleScript(
                "tell application \"\(name)\" to get URL of front document"
            )
        default:
            return nil
        }
    }

    private static func runAppleScript(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        guard error == nil else { return nil }
        return result.stringValue
    }
}
