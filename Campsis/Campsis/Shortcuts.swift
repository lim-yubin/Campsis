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
    static let triggerQuickMemory = Notification.Name("triggerQuickMemory")
    static let captureSaved = Notification.Name("captureSaved")
    static let requestNewChat = Notification.Name("requestNewChat")
    static let aiSettingsChanged = Notification.Name("aiSettingsChanged")
}

/// AI 생성 제공자 선택 (D36, D38). AppStorage 키 "aiProvider"에 rawValue 저장.
enum AIProvider: String, CaseIterable, Identifiable {
    case local
    case luna

    var id: String { rawValue }

    var label: String {
        switch self {
        case .local: return "로컬 (Qwen3-4B)"
        case .luna: return "GPT-5.6 Luna (클라우드)"
        }
    }

    var detail: String {
        switch self {
        case .local: return "완전 오프라인·무료. 기기 메모리를 사용하며 품질은 제한적입니다."
        case .luna: return "높은 품질. 답변 생성 시 질문과 관련 메모만 OpenAI로 전송됩니다. API 키 필요."
        }
    }
}
