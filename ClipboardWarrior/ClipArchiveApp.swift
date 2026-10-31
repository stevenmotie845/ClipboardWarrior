import AppKit
import SwiftData
import SwiftUI

@main
struct ClipboardWarriorApp: App {
    private let container: ModelContainer
    @State private var monitor: ClipboardMonitor
    @State private var globalHotKey: GlobalHotKey

    init() {
        Pref.register()

        let container: ModelContainer
        do {
            container = try ModelContainer(for: ClipItem.self, ClipCategory.self)
        } catch {
            fatalError("Couldn't open the clip database: \(error)")
        }
        self.container = container

        let monitor = ClipboardMonitor(context: container.mainContext)
        monitor.start()
        _monitor = State(initialValue: monitor)
        let hotKey = GlobalHotKey()
        hotKey.start(enabled: UserDefaults.standard.bool(forKey: Pref.globalHotKey))
        _globalHotKey = State(initialValue: hotKey)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(monitor)
                .modelContainer(container)
        } label: {
            MenuBarLabel(monitor: monitor)
        }
        .menuBarExtraStyle(.window)

        Window("Clipboard Warrior", id: "archive") {
            ArchiveView()
                .environment(monitor)
                .modelContainer(container)
        }

        Settings {
            SettingsView()
                .environment(monitor)
                .modelContainer(container)
        }
    }
}

/// The menu bar icon. Unlike the popover, this view is alive the whole time the app runs, so it
/// is the right place to listen for the global shortcut and open the archive window.
private struct MenuBarLabel: View {
    let monitor: ClipboardMonitor
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: monitor.isPaused ? "pause.circle" : "doc.on.clipboard")
            .onReceive(NotificationCenter.default.publisher(for: .clipboardWarriorShowArchive)) { _ in
                NSApp.activate()
                openWindow(id: "archive")
            }
    }
}
