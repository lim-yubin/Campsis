import SwiftUI
import KeyboardShortcuts

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

    @available(macOS 26.0, *)
    var chatEngine: ChatEngine? { chatEngineRef as? ChatEngine }

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

        if #available(macOS 26.0, *) {
            let generator = AppleFMGenerator()
            let queue = ProcessingQueue(
                repository: repo,
                generator: generator,
                embeddingService: embedService,
                embeddingRepository: embedRepo
            )
            processingQueue = queue
            appState.processingQueueRef = queue
            coordinator = CaptureCoordinator(repository: repo, processingQueue: queue)

            let searchEngine = VectorSearchEngine(
                embeddingService: embedService,
                embeddingRepository: embedRepo,
                sourceRepository: repo
            )
            let chatEngine = ChatEngine(
                searchEngine: searchEngine,
                conversationRepository: appState.conversationRepository,
                messageRepository: appState.messageRepository,
                sourceRepository: repo
            )
            appState.chatEngineRef = chatEngine

            Task {
                await queue.processAllPending()
                await queue.embedAllMissing()
            }
        } else {
            coordinator = CaptureCoordinator(repository: repo, processingQueue: nil)
        }

        NSLog("[Campsis] Coordinator initialized, shortcuts registered")
    }
}
