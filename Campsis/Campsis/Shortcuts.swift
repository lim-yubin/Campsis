import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let rememberContext = Self("rememberContext", initial: .init(.space, modifiers: .option))
    static let quickMemory = Self("quickMemory", initial: .init(.space, modifiers: [.option, .shift]))
}
