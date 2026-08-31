import SwiftUI
import KeyboardShortcuts
import MLXLMCommon

@main
struct CampsisApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Campsis", systemImage: "brain.head.profile") {
            MenuBarView()
        }

        Window("Campsis Memory", id: "main") {
            MainContentView()
                .environment(appDelegate.appState)
        }
        .defaultSize(width: 900, height: 640)
        .defaultLaunchBehavior(.presented)

        Settings {
            SettingsView()
        }
    }
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

        Task.detached { [weak self] in
            guard let self else { return }
            let appState = await MainActor.run { self }
            let chatEngine = await MainActor.run { appState.chatEngine }
            let messageRepository = await MainActor.run { appState.messageRepository }
            let sourceRepository = await MainActor.run { appState.sourceRepository }
            let conversationRepository = await MainActor.run { appState.conversationRepository }

            var content: String
            var sourceIds: [String] = []

            guard let chatEngine else {
                content = "AI 모델을 로딩 중입니다. 잠시 후 다시 시도해 주세요."
                await self.saveAndNotify(content: content, sourceIds: sourceIds,
                                         conversationId: conversationId, query: query,
                                         messageRepository: messageRepository,
                                         sourceRepository: sourceRepository,
                                         conversationRepository: conversationRepository)
                return
            }

            do {
                let response = try await chatEngine.send(query: query, conversationId: conversationId)
                content = response.answer
                sourceIds = response.sources.map { $0.source.id }
            } catch {
                content = "오류가 발생했습니다: \(error.localizedDescription)"
            }

            await self.saveAndNotify(content: content, sourceIds: sourceIds,
                                     conversationId: conversationId, query: query,
                                     messageRepository: messageRepository,
                                     sourceRepository: sourceRepository,
                                     conversationRepository: conversationRepository)
        }
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
        if messageCount <= 2 {
            let title = String(query.prefix(40))
            if var conv = try? conversationRepository.fetch(id: conversationId) {
                conv.title = title
                try? conversationRepository.update(&conv)
            }
        }

        await MainActor.run {
            pendingConversations.remove(conversationId)
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
        }
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let showDock = UserDefaults.standard.object(forKey: "showDockIcon") as? Bool ?? true
        NSApp.setActivationPolicy(showDock ? .regular : .accessory)

        let repo = appState.sourceRepository
        let embedRepo = appState.embeddingRepository
        let embedService = appState.embeddingService

        coordinator = CaptureCoordinator(repository: repo, processingQueue: nil)
        NSLog("[Campsis] Coordinator initialized, shortcuts registered")

        Task {
            await self.initializeModels(repo: repo, embedRepo: embedRepo, embedService: embedService)
        }
    }

    private func initializeModels(repo: SourceRepository, embedRepo: EmbeddingRepository, embedService: EmbeddingService) async {
        let mlxGenerator = MLXGenerator()
        var generator: TextGenerator = mlxGenerator

        var mlxContainer: ModelContainer?
        do {
            try await mlxGenerator.preload()
            mlxContainer = await mlxGenerator.getLoadedContainer()
            NSLog("[Campsis] MLX model loaded — using Qwen3-4B for analysis and chat")
        } catch {
            NSLog("[Campsis] MLX model unavailable (\(error.localizedDescription)), falling back to Apple FM")
            if #available(macOS 26.0, *) {
                generator = AppleFMGenerator()
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

        let searchEngine = VectorSearchEngine(
            embeddingService: embedService,
            embeddingRepository: embedRepo,
            sourceRepository: repo
        )

        if let container = mlxContainer {
            let chatEngine = MLXChatEngine(
                searchEngine: searchEngine,
                conversationRepository: appState.conversationRepository,
                messageRepository: appState.messageRepository,
                sourceRepository: repo,
                modelContainer: container
            )
            await MainActor.run {
                appState.chatEngineRef = chatEngine
            }
        } else if #available(macOS 26.0, *) {
            let chatEngine = AppleFMChatEngine(
                searchEngine: searchEngine,
                conversationRepository: appState.conversationRepository,
                messageRepository: appState.messageRepository,
                sourceRepository: repo
            )
            await MainActor.run {
                appState.chatEngineRef = chatEngine
            }
        }

        Task {
            await queue.processAllPending()
            await queue.embedAllMissing()
        }
    }
}
