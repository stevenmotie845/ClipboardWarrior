import AppKit
import SwiftUI

@MainActor
enum WindowActivation {
    static func activateApp() {
        NSApp.activate()
    }

    static func activateAndRaiseKeyWindow() {
        activateApp()
        NSApp.keyWindow?.makeKeyAndOrderFront(nil)
    }

    static func bringWindowToFront(titled title: String) {
        activateApp()
        guard let window = NSApp.windows.first(where: { $0.title == title }) else { return }
        window.makeKeyAndOrderFront(nil)
    }
}

/// Attaches to a SwiftUI-hosted window and raises that window when it is created or shown.
struct WindowFrontmostBridge: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowActivationView {
        WindowActivationView()
    }

    func updateNSView(_ nsView: WindowActivationView, context: Context) {}
}

@MainActor
final class WindowActivationView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        DispatchQueue.main.async { [weak self] in
            guard let window = self?.window else { return }
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
        }
    }
}
