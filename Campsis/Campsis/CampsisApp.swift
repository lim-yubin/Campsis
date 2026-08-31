import SwiftUI
import KeyboardShortcuts
import MLXLMCommon

@main
struct CampsisApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Campsis", systemImage: "brain.head.profile") {
            MenuBarView()
                .environment(appDelegate.appState)
        }

        Window("Campsis Memory", id: "main") {
            MainContentView()
                .environment(appDelegate.appState)
        }
        .defaultSize(width: 900, height: 640)
        .defaultLaunchBehavior(.presented)
        .commands { CampsisCommands() }

        Settings {
            SettingsView()
        }
    }
}

/// Dock 앱(.regular)에서 화면 상단 앱 메뉴바에 노출되는 명령. 전역 단축키를 몰라도 발견 가능.
struct CampsisCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("새 채팅") {
                openMain()
                postDelayed(.requestNewChat)
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("빠른 메모") {
                NotificationCenter.default.post(name: .triggerQuickMemory, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Divider()

            Button("메모리 열기") {
                openMain()
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
        }
    }

    private func openMain() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 창이 방금 열렸을 수 있으므로, 뷰가 알림을 구독할 시간을 준 뒤 전송한다.
    private func postDelayed(_ name: Notification.Name) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NotificationCenter.default.post(name: name, object: nil)
        }
    }
}

enum ModelStatus: Equatable {
    case idle
    case downloading(Double)
    case loading
    case ready
    case failed

    var label: String {
        switch self {
        case .idle: return "AI 준비 중…"
        case .downloading(let fraction):
            return "AI 모델 다운로드 중… \(Int(fraction * 100))%"
        case .loading: return "AI 모델 로딩 중…"
        case .ready: return "AI 준비됨"
        case .failed: return "AI 사용 불가"
        }
    }

    var isReady: Bool { self == .ready }
}

@Observable
@MainActor
final class AppState {
    let sourceRepository: SourceRepository
    let embeddingRepository: EmbeddingRepository
    let embeddingService: EmbeddingService
    let conversationRepository: ConversationRepository
    let messageRepository: MessageRepository
    var processingQueueRef: (any Sendable)?
    var chatEngineRef: (any Sendable)?
    var pendingConversations: Set<String> = []
    var modelStatus: ModelStatus = .idle
    var streamingText: [String: String] = [:]
    private var generationTasks: [String: Task<Void, Never>] = [:]

    var chatEngine: (any ChatEngineProtocol)? { chatEngineRef as? (any ChatEngineProtocol) }

    init(sourceRepository: SourceRepository, embeddingRepository: EmbeddingRepository,
         embeddingService: EmbeddingService, conversationRepository: ConversationRepository,
         messageRepository: MessageRepository) {
        self.sourceRepository = sourceRepository
        self.embeddingRepository = embeddingRepository
        self.embeddingService = embeddingService
        self.conversationRepository = conversationRepository
        self.messageRepository = messageRepository
    }

    func generateResponse(for query: String, conversationId: String) {
        pendingConversations.insert(conversationId)
        streamingText[conversationId] = ""

        let task = Task.detached { [weak self] in
            guard let self else { return }
            let appState = await MainActor.run { self }
            let chatEngine = await MainActor.run { appState.chatEngine }
            let messageRepository = await MainActor.run { appState.messageRepository }
            let sourceRepository = await MainActor.run { appState.sourceRepository }
            let conversationRepository = await MainActor.run { appState.conversationRepository }

            guard let chatEngine else {
                await self.saveAndNotify(content: "AI 모델을 로딩 중입니다. 잠시 후 다시 시도해 주세요.",
                                         sourceIds: [], conversationId: conversationId, query: query,
                                         messageRepository: messageRepository,
                                         sourceRepository: sourceRepository,
                                         conversationRepository: conversationRepository)
                return
            }

            var content = ""
            var sourceIds: [String] = []

            do {
                let response = try await chatEngine.sendStream(query: query, conversationId: conversationId) { delta in
                    Task { @MainActor in
                        appState.streamingText[conversationId, default: ""] += delta
                    }
                }
                content = response.answer
                sourceIds = response.sources.map { $0.source.id }
            } catch is CancellationError {
                let partial = await MainActor.run { appState.streamingText[conversationId] ?? "" }
                content = partial.trimmingCharacters(in: .whitespacesAndNewlines)
                if content.isEmpty {
                    await self.finishGeneration(conversationId: conversationId)
                    return
                }
                content += "\n\n_(중지됨)_"
            } catch {
                content = Self.friendlyErrorMessage(error)
            }

            await self.saveAndNotify(content: content, sourceIds: sourceIds,
                                     conversationId: conversationId, query: query,
                                     messageRepository: messageRepository,
                                     sourceRepository: sourceRepository,
                                     conversationRepository: conversationRepository)
        }
        generationTasks[conversationId] = task
    }

    func stopGeneration(conversationId: String) {
        generationTasks[conversationId]?.cancel()
    }

    nonisolated static let contextErrorPrefix = "⚠️ 대화가 너무 길어졌어요."

    nonisolated static func friendlyErrorMessage(_ error: Error) -> String {
        let desc = error.localizedDescription.lowercased()
        if desc.contains("context") || desc.contains("window") || desc.contains("memory") {
            return contextErrorPrefix + " 아래 '새 채팅 시작'을 눌러 새 대화를 시작해 주세요."
        }
        return "⚠️ 답변 생성 중 문제가 발생했어요. 잠시 후 다시 시도해 주세요.\n(\(error.localizedDescription))"
    }

    private func finishGeneration(conversationId: String) {
        pendingConversations.remove(conversationId)
        streamingText[conversationId] = nil
        generationTasks[conversationId] = nil
        NotificationCenter.default.post(
            name: .chatResponseCompleted,
            object: nil,
            userInfo: ["conversationId": conversationId]
        )
    }

    private func saveAndNotify(content: String, sourceIds: [String],
                               conversationId: String, query: String,
                               messageRepository: MessageRepository,
                               sourceRepository: SourceRepository,
                               conversationRepository: ConversationRepository) async {
        var msg = Message(conversationId: conversationId, role: .assistant, content: content, sourceIds: sourceIds)
        do {
            try messageRepository.save(&msg)
        } catch {
            NSLog("[Campsis] Failed to save assistant message: \(error)")
        }

        let messageCount = (try? messageRepository.fetchAll(conversationId: conversationId).count) ?? 0
        let isErrorContent = content.hasPrefix("⚠️") || content.hasPrefix("AI 모델을 로딩")
        if messageCount <= 2 {
            var title = String(query.prefix(40))
            if !isErrorContent, let engine = chatEngine,
               let suggested = await engine.suggestTitle(for: query, answer: content) {
                title = suggested
            }
            if var conv = try? conversationRepository.fetch(id: conversationId) {
                conv.title = title
                try? conversationRepository.update(&conv)
            }
        }

        await MainActor.run {
            pendingConversations.remove(conversationId)
            streamingText[conversationId] = nil
            generationTasks[conversationId] = nil
            NotificationCenter.default.post(
                name: .chatResponseCompleted,
                object: nil,
                userInfo: ["conversationId": conversationId]
            )
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: CaptureCoordinator?
    private var processingQueue: ProcessingQueue?
    private var searchEngine: VectorSearchEngine?
    private var mlxContainer: ModelContainer?
    @MainActor let appState: AppState = {
        let db = try! AppDatabase.makeDefault()
        let repo = SourceRepository(dbQueue: db.dbQueue)
        let embedRepo = EmbeddingRepository(dbQueue: db.dbQueue)
        let embedService = EmbeddingService()
        let convRepo = ConversationRepository(dbQueue: db.dbQueue)
        let msgRepo = MessageRepository(dbQueue: db.dbQueue)
        return AppState(sourceRepository: repo, embeddingRepository: embedRepo,
                       embeddingService: embedService, conversationRepository: convRepo,
                       messageRepository: msgRepo)
    }()

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NotificationCenter.default.post(name: .openMemoryWindow, object: nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        return true
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(dockMenuItem("빠른 메모", #selector(dockQuickMemory)))
        menu.addItem(dockMenuItem("새 채팅", #selector(dockNewChat)))
        menu.addItem(dockMenuItem("메모리 열기", #selector(dockOpenMemory)))
        return menu
    }

    private func dockMenuItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func dockQuickMemory() {
        NotificationCenter.default.post(name: .triggerQuickMemory, object: nil)
    }

    @objc private func dockOpenMemory() {
        NotificationCenter.default.post(name: .openMemoryWindow, object: nil)
    }

    @objc private func dockNewChat() {
        NotificationCenter.default.post(name: .openMemoryWindow, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NotificationCenter.default.post(name: .requestNewChat, object: nil)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let showDock = UserDefaults.standard.object(forKey: "showDockIcon") as? Bool ?? true
        NSApp.setActivationPolicy(showDock ? .regular : .accessory)

        let repo = appState.sourceRepository
        let embedRepo = appState.embeddingRepository
        let embedService = appState.embeddingService

        coordinator = CaptureCoordinator(repository: repo, processingQueue: nil)
        NSLog("[Campsis] Coordinator initialized, shortcuts registered")

        NotificationCenter.default.addObserver(
            forName: .aiSettingsChanged, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.configureChatEngine()
            }
        }

        Task {
            await self.initializeModels(repo: repo, embedRepo: embedRepo, embedService: embedService)
        }
    }

    private func initializeModels(repo: SourceRepository, embedRepo: EmbeddingRepository, embedService: EmbeddingService) async {
        let state = appState
        await MainActor.run { state.modelStatus = .idle }

        let mlxGenerator = MLXGenerator()
        var generator: TextGenerator = mlxGenerator

        var loadedContainer: ModelContainer?
        do {
            try await mlxGenerator.preload(onProgress: { fraction in
                Task { @MainActor in
                    state.modelStatus = fraction < 1.0 ? .downloading(fraction) : .loading
                }
            })
            loadedContainer = await mlxGenerator.getLoadedContainer()
            await MainActor.run { state.modelStatus = .ready }
            NSLog("[Campsis] MLX model loaded — using Qwen3-4B for analysis and chat")
        } catch {
            NSLog("[Campsis] MLX model unavailable (\(error.localizedDescription)), falling back to Apple FM")
            if #available(macOS 26.0, *) {
                generator = AppleFMGenerator()
                await MainActor.run { state.modelStatus = .ready }
            } else {
                await MainActor.run { state.modelStatus = .failed }
            }
        }

        let queue = ProcessingQueue(
            repository: repo,
            generator: generator,
            embeddingService: embedService,
            embeddingRepository: embedRepo
        )
        processingQueue = queue

        await MainActor.run {
            appState.processingQueueRef = queue
        }

        coordinator?.updateProcessingQueue(queue)

        let engine = VectorSearchEngine(
            embeddingService: embedService,
            embeddingRepository: embedRepo,
            sourceRepository: repo
        )

        await MainActor.run {
            self.searchEngine = engine
            self.mlxContainer = loadedContainer
            self.configureChatEngine()
        }

        let markdownGenerator = await MainActor.run { self.makeMarkdownGenerator() }
        await queue.setMarkdownGenerator(markdownGenerator)

        Task {
            await queue.processAllPending()
            await queue.embedAllMissing()
            await queue.generateMissingMarkdown()
        }
    }

    /// 현재 설정(provider + 키)에 맞는 MD 생성기를 만든다. 로컬 전용이면 nil.
    @MainActor
    private func makeMarkdownGenerator() -> MarkdownGenerator? {
        let providerRaw = UserDefaults.standard.string(forKey: "aiProvider") ?? AIProvider.local.rawValue
        let provider = AIProvider(rawValue: providerRaw) ?? .local
        if provider == .luna, let key = AICredentials.openAIKey, !key.isEmpty {
            return LunaMarkdownGenerator(apiKey: key)
        }
        return nil
    }

    /// 설정 변경 시 MD 생성기를 갱신하고, 밀린 MD 생성을 시도한다.
    @MainActor
    private func updateMarkdownGenerator() {
        guard let queue = processingQueue else { return }
        let generator = makeMarkdownGenerator()
        Task {
            await queue.setMarkdownGenerator(generator)
            await queue.generateMissingMarkdown()
        }
    }

    /// 설정(AI 제공자 + API 키)에 따라 채팅 엔진을 구성한다. 설정 변경 시 재호출된다.
    @MainActor
    private func configureChatEngine() {
        updateMarkdownGenerator()

        guard let searchEngine else { return }

        let providerRaw = UserDefaults.standard.string(forKey: "aiProvider") ?? AIProvider.local.rawValue
        let provider = AIProvider(rawValue: providerRaw) ?? .local

        if provider == .luna, let key = AICredentials.openAIKey, !key.isEmpty {
            appState.chatEngineRef = LunaChatEngine(
                searchEngine: searchEngine,
                messageRepository: appState.messageRepository,
                apiKey: key
            )
            NSLog("[Campsis] Chat engine → GPT-5.6 Luna (cloud)")
            return
        }

        if let container = mlxContainer {
            appState.chatEngineRef = MLXChatEngine(
                searchEngine: searchEngine,
                conversationRepository: appState.conversationRepository,
                messageRepository: appState.messageRepository,
                sourceRepository: appState.sourceRepository,
                modelContainer: container
            )
            NSLog("[Campsis] Chat engine → local MLX (Qwen3-4B)")
        } else if #available(macOS 26.0, *) {
            appState.chatEngineRef = AppleFMChatEngine(
                searchEngine: searchEngine,
                conversationRepository: appState.conversationRepository,
                messageRepository: appState.messageRepository,
                sourceRepository: appState.sourceRepository
            )
            NSLog("[Campsis] Chat engine → Apple FM fallback")
        }
    }
}
