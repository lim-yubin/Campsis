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
    /// 위키가 생성/재합성되어 목록·상세를 새로고침해야 할 때(Phase 8).
    static let wikiUpdated = Notification.Name("wikiUpdated")
    /// 채팅 출처(위키 배지) 클릭 등으로 특정 위키를 열어야 할 때(Phase 8.8). `AppState.pendingWikiId` 사용.
    static let openWiki = Notification.Name("openWiki")
    /// 원본 외부 편집 후 정리본이 재생성되어 상세/인스펙터를 새로고침해야 할 때. userInfo["id"] = sourceId.
    static let sourceReprocessed = Notification.Name("sourceReprocessed")
}

/// AI 생성 제공자 (D36, D38, D48). AppStorage 키 "aiProvider"에 rawValue 저장.
/// 로컬 LLM(Qwen/Apple FM)은 제거되어 클라우드(Luna)만 지원한다 (always-online 전제).
enum AIProvider: String, CaseIterable, Identifiable {
    case luna

    var id: String { rawValue }

    var label: String {
        switch self {
        case .luna: return "GPT-5.6 Luna (클라우드)"
        }
    }

    var detail: String {
        switch self {
        case .luna: return "답변 생성 시 질문과 관련 메모만 OpenAI로 전송됩니다. API 키가 필요합니다."
        }
    }
}
