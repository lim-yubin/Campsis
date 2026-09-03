import AppKit
import ScreenCaptureKit

enum ScreenshotCapture {
    static func capture() async -> CapturedScreenshot? {
        guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) else {
            return nil
        }

        let mouseLocation = NSEvent.mouseLocation
        let display = content.displays.first { scDisplay in
            let frame = CGDisplayBounds(scDisplay.displayID)
            let flippedY = NSScreen.screens.first.map { $0.frame.maxY - frame.maxY } ?? 0
            let nsRect = NSRect(x: frame.origin.x, y: flippedY, width: frame.width, height: frame.height)
            return nsRect.contains(mouseLocation)
        } ?? content.displays.first

        guard let display else { return nil }

        let (appName, windowTitle) = contextForMouseLocation(mouseLocation, windows: content.windows, display: display)

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let config = SCStreamConfiguration()
        // SCDisplay.width/height는 포인트 단위이고 스케일이 디스플레이마다 다르므로
        // 하드코딩 *2는 스케일 1 디스플레이(외장 모니터 등)에서 캔버스를 2배로 부풀려
        // 우측·하단에 검은 여백을 만든다. 실제 네이티브 픽셀 해상도를 사용한다.
        let mode = CGDisplayCopyDisplayMode(display.displayID)
        let pixelWidth = mode?.pixelWidth ?? Int(display.width)
        let pixelHeight = mode?.pixelHeight ?? Int(display.height)
        config.width = pixelWidth
        config.height = pixelHeight
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false

        guard let image = try? await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        ) else { return nil }

        // 논리 크기는 포인트 단위로 둬 화면 표시 시 올바른 크기를 갖게 한다.
        let nsImage = NSImage(cgImage: image, size: NSSize(width: display.width, height: display.height))

        guard let savedPath = saveScreenshot(nsImage) else { return nil }

        return CapturedScreenshot(
            image: nsImage,
            savedPath: savedPath,
            application: appName,
            windowTitle: windowTitle,
            url: nil
        )
    }

    private static func contextForMouseLocation(_ mouse: NSPoint, windows: [SCWindow], display: SCDisplay) -> (String?, String?) {
        _ = CGDisplayBounds(display.displayID)
        let screenHeight = NSScreen.screens.first?.frame.maxY ?? 0

        let topmostWindow = windows.first { window in
            guard window.isOnScreen,
                  window.frame.width > 0,
                  window.frame.height > 0,
                  !(window.title?.isEmpty ?? true),
                  window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
            else { return false }

            let wf = window.frame
            let flippedY = screenHeight - wf.origin.y - wf.height
            let nsRect = NSRect(x: wf.origin.x, y: flippedY, width: wf.width, height: wf.height)
            return nsRect.contains(mouse)
        }

        if let window = topmostWindow {
            return (window.owningApplication?.applicationName, window.title)
        }

        let fallback = NSWorkspace.shared.frontmostApplication
        return (fallback?.localizedName, nil)
    }

    private static func saveScreenshot(_ image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        let filename = "capture-\(ISO8601DateFormatter().string(from: Date())).png"
            .replacingOccurrences(of: ":", with: "-")
        let url = AppPaths.screenshots.appending(path: filename)

        do {
            try AppPaths.ensureDirectories()
            try pngData.write(to: url)
            // 저장 직후 격리 속성 제거 + 쓰기 권한 보장 → 미리보기에서 원본 제자리 편집 가능
            AppPaths.prepareForInPlaceEditing(url)
            return AppPaths.relativePath(from: url)
        } catch {
            return nil
        }
    }
}
