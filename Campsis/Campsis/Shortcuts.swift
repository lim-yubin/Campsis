import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let rememberContext = Self("rememberContext", initial: .init(.space, modifiers: .option))
    static let quickMemory = Self("quickMemory", initial: .init(.space, modifiers: [.option, .shift]))
    static let openMemory = Self("openMemory", initial: .init(.m, modifiers: [.option, .shift]))
}

extension Notification.Name {
    static let openMemoryWindow = Notification.Name("openMemoryWindow")
    static let chatResponseCompleted = Notification.Name("chatResponseCompleted")
}
