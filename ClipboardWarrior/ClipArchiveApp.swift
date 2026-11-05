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
        Self.repairBoardIcons(in: container.mainContext)

        let monitor = ClipboardMonitor(context: container.mainContext)
        monitor.start()
        _monitor = State(initialValue: monitor)

        let hotKey = GlobalHotKey()
        hotKey.start()
        _globalHotKey = State(initialValue: hotKey)

        QuickPasteController.shared.configure(container: container, monitor: monitor)
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

        Window("ClipboardWarrior", id: "archive") {
            ArchiveView()
                .environment(monitor)
                .modelContainer(container)
        }
        .commands {
            ClipCommands(monitor: monitor)
        }

        Window("Welcome to ClipboardWarrior", id: "onboarding") {
            OnboardingView()
                .environment(monitor)
                .modelContainer(container)
        }

        Settings {
            SettingsView()
                .environment(monitor)
                .modelContainer(container)
        }
    }

    /// Boards created with the old "Code" icon stored `code`, which is not a real SF Symbol and
    /// rendered blank. Point them at the correct symbol.
    private static func repairBoardIcons(in context: ModelContext) {
        guard let boards = try? context.fetch(FetchDescriptor<ClipCategory>()) else { return }
        var changed = false
        for board in boards {
            let fixed = CWSymbol.resolved(board.symbol)
            if fixed != board.symbol {
                board.symbol = fixed
                changed = true
            }
        }
        if changed { try? context.save() }
    }
}

/// Menu bar commands, available whenever the archive window is in front.
struct ClipCommands: Commands {
    let monitor: ClipboardMonitor

    var body: some Commands {
        CommandMenu("Clips") {
            Button("Quick Paste…") { QuickPasteController.shared.toggle() }
            Divider()
            Button("Clear Pinned Clips…") { monitor.confirmDeletePinnedClips() }
            Button("Delete All Clips…") { monitor.confirmDeleteAllClips() }
                .keyboardShortcut(.delete, modifiers: [.command, .shift])
        }
    }
}

/// The menu bar icon. Unlike the popover, this view is alive the whole time the app runs, so it
/// is the right place to listen for the global shortcut and open the archive window.
private struct MenuBarLabel: View {
    let monitor: ClipboardMonitor
    @Environment(\.openWindow) private var openWindow
    @AppStorage(Pref.onboardingComplete) private var onboardingComplete = false

    var body: some View {
        Image(systemName: monitor.isPaused ? "pause.circle" : "doc.on.clipboard")
            .accessibilityLabel(monitor.isPaused ? "ClipboardWarrior, capture paused" : "ClipboardWarrior")
            .onReceive(NotificationCenter.default.publisher(for: .clipboardWarriorShowArchive)) { _ in
                WindowActivation.activateApp()
                openWindow(id: "archive")
                DispatchQueue.main.async {
                    WindowActivation.bringWindowToFront(titled: "ClipboardWarrior")
                }
            }
            .task {
                guard !onboardingComplete else { return }
                onboardingComplete = false
                WindowActivation.activateApp()
                openWindow(id: "onboarding")
                DispatchQueue.main.async {
                    WindowActivation.bringWindowToFront(titled: "Welcome to ClipboardWarrior")
                }
            }
    }
}
