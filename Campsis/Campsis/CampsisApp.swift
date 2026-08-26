import SwiftUI
import KeyboardShortcuts

@main
struct CampsisApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Campsis", systemImage: "brain.head.profile") {
            MenuBarView()
        }

        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: CaptureCoordinator?
    private var processingQueue: ProcessingQueue?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let db = try AppDatabase.makeDefault()
            let repo = SourceRepository(dbQueue: db.dbQueue)

            if #available(macOS 26.0, *) {
                let generator = AppleFMGenerator()
                let queue = ProcessingQueue(repository: repo, generator: generator)
                processingQueue = queue
                coordinator = CaptureCoordinator(repository: repo, processingQueue: queue)
                Task { await queue.processAllPending() }
            } else {
                coordinator = CaptureCoordinator(repository: repo, processingQueue: nil)
            }

            NSLog("[Campsis] Coordinator initialized, shortcuts registered")
        } catch {
            fatalError("Database initialization failed: \(error)")
        }
    }
}
