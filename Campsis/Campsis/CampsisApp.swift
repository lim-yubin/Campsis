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

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let db = try AppDatabase.makeDefault()
            let repo = SourceRepository(dbQueue: db.dbQueue)
            coordinator = CaptureCoordinator(repository: repo)
            NSLog("[Campsis] Coordinator initialized, shortcuts registered")
        } catch {
            fatalError("Database initialization failed: \(error)")
        }
    }
}
