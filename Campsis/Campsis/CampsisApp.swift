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

    func applicationDidFinishLaunching(_ notification: Notification) {
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
