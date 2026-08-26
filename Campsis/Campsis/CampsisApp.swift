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
    var processingQueueRef: (any Sendable)?

    init(sourceRepository: SourceRepository, embeddingRepository: EmbeddingRepository,
         embeddingService: EmbeddingService) {
        self.sourceRepository = sourceRepository
        self.embeddingRepository = embeddingRepository
        self.embeddingService = embeddingService
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
        return AppState(sourceRepository: repo, embeddingRepository: embedRepo,
                       embeddingService: embedService)
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
