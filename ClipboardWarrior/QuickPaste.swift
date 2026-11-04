import AppKit
import ApplicationServices
import Carbon
import SwiftData
import SwiftUI

// MARK: - Panel

/// Floating, non-activating panel. The app you were typing in stays frontmost, so the chosen clip
/// can be pasted straight into it.
private final class QuickPastePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        close()
    }
}

// MARK: - Controller

@MainActor
final class QuickPasteController {
    static let shared = QuickPasteController()

    private var panel: QuickPastePanel?
    private var container: ModelContainer?
    private var monitor: ClipboardMonitor?
    private var hotKeyObserver: NSObjectProtocol?
    private var activationObserver: NSObjectProtocol?
    private var resignObserver: NSObjectProtocol?
    private var lastExternalApp: NSRunningApplication?

    private static let panelSize = NSSize(width: 500, height: 470)

    func configure(container: ModelContainer, monitor: ClipboardMonitor) {
        self.container = container
        self.monitor = monitor

        if hotKeyObserver == nil {
            hotKeyObserver = NotificationCenter.default.addObserver(
                forName: .clipboardWarriorQuickPaste, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.toggle() }
            }
        }

        // Remember the last app that wasn't ClipboardWarrior, so "Quick Paste…" chosen from our own
        // menu bar popover still knows where to paste.
        if activationObserver == nil {
            activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
            ) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                MainActor.assumeIsolated {
                    guard let app, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
                    self?.lastExternalApp = app
                }
            }
        }
        if let front = NSWorkspace.shared.frontmostApplication,
           front.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            lastExternalApp = front
        }
    }

    func toggle() {
        if let panel, panel.isVisible { close() } else { show() }
    }

    func show() {
        guard let container, let monitor else { return }
        close()

        let root = QuickPasteView(
            onPick: { [weak self] item in self?.paste(item) },
            onClose: { [weak self] in self?.close() }
        )
        .environment(monitor)
        .modelContainer(container)

        let hosting = NSHostingController(rootView: root)
        let panel = QuickPastePanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hosting
        panel.setContentSize(Self.panelSize)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Centre on the screen the pointer is on, slightly above the middle.
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            let origin = NSPoint(x: visible.midX - Self.panelSize.width / 2,
                                 y: visible.midY - Self.panelSize.height / 2 + visible.height * 0.08)
            panel.setFrameOrigin(origin)
        }

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }

        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
            self.resignObserver = nil
        }
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
    }

    // MARK: Paste

    private var pasteTarget: NSRunningApplication? {
        let ours = ProcessInfo.processInfo.processIdentifier
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != ours { return front }
        return lastExternalApp
    }

    /// Puts the clip on the clipboard, then sends ⌘V to the app you were using.
    private func paste(_ item: ClipItem) {
        guard let monitor else { return }
        let target = pasteTarget
        monitor.copyBack(item)
        close()

        guard Self.accessibilityGranted(prompt: true) else {
            monitor.postNote("Copied. Allow Accessibility in System Settings to paste automatically.")
            return
        }

        // Give the panel a moment to disappear and focus to return to the target app.
        let needsActivation = NSWorkspace.shared.frontmostApplication?.processIdentifier != target?.processIdentifier
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            if needsActivation { target?.activate() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (needsActivation ? 0.18 : 0.05)) {
                Self.sendPasteKeystroke()
            }
        }
    }

    static func accessibilityGranted(prompt: Bool) -> Bool {
        // Literal value of kAXTrustedCheckOptionPrompt.
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private static func sendPasteKeystroke() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let key = CGKeyCode(kVK_ANSI_V)
        let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cgSessionEventTap)
        up?.post(tap: .cgSessionEventTap)
    }
}

// MARK: - View

struct QuickPasteView: View {
    let onPick: (ClipItem) -> Void
    let onClose: () -> Void

    @Query private var clips: [ClipItem]
    @State private var search = ""
    @State private var selectedIndex = 0
    @State private var canAutoPaste = QuickPasteController.accessibilityGranted(prompt: false)
    @FocusState private var searchFocused: Bool

    init(onPick: @escaping (ClipItem) -> Void, onClose: @escaping () -> Void) {
        self.onPick = onPick
        self.onClose = onClose
        var descriptor = FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\ClipItem.lastCopiedAt, order: .reverse)])
        descriptor.fetchLimit = 400
        _clips = Query(descriptor)
    }

    private var results: [ClipItem] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return Array(clips.prefix(120)) }
        return clips.filter {
            $0.preview.localizedStandardContains(query)
            || $0.sourceApp.localizedStandardContains(query)
            || $0.tags.localizedStandardContains(query)
            || (!$0.isSensitive && $0.text.localizedStandardContains(query))
        }
    }

    var body: some View {
        let items = results
        VStack(spacing: 0) {
            searchField
            Divider().overlay(CWStyle.separator)

            if items.isEmpty {
                ContentUnavailableView(
                    search.isEmpty ? "No clips yet" : "No matching clips",
                    systemImage: search.isEmpty ? "doc.on.clipboard" : "magnifyingglass",
                    description: Text(search.isEmpty ? "Copy something and it will appear here." : "Try a different search.")
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(items.enumerated()), id: \.element.persistentModelID) { index, item in
                                QuickPasteRow(item: item, index: index, isSelected: index == selectedIndex)
                                    .id(index)
                                    .onTapGesture { onPick(item) }
                            }
                        }
                        .padding(8)
                    }
                    .onChange(of: selectedIndex) { _, newValue in
                        proxy.scrollTo(newValue)
                    }
                }
            }

            Divider().overlay(CWStyle.separator)
            hints
        }
        .frame(width: 500, height: 470)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onChange(of: search) { _, _ in selectedIndex = 0 }
        .onKeyPress(.downArrow) { move(1, count: items.count); return .handled }
        .onKeyPress(.upArrow) { move(-1, count: items.count); return .handled }
        .onKeyPress(.escape) { onClose(); return .handled }
        .onKeyPress(characters: CharacterSet(charactersIn: "123456789"), phases: .down) { press in
            guard press.modifiers.contains(.command),
                  let number = Int(String(press.characters)),
                  number - 1 < items.count else { return .ignored }
            onPick(items[number - 1])
            return .handled
        }
        .task {
            try? await Task.sleep(for: .milliseconds(60))
            searchFocused = true
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Search clips, then press Return to paste", text: $search)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .focused($searchFocused)
                .onSubmit {
                    let items = results
                    guard items.indices.contains(selectedIndex) else { return }
                    onPick(items[selectedIndex])
                }
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var hints: some View {
        HStack(spacing: 14) {
            hint("↩", "Paste")
            hint("↑↓", "Navigate")
            hint("⌘1–9", "Quick pick")
            hint("esc", "Close")
            Spacer(minLength: 0)
            if !canAutoPaste {
                Button {
                    _ = QuickPasteController.accessibilityGranted(prompt: true)
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Enable auto-paste", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(CWStyle.warning)
                }
                .buttonStyle(.plain)
                .help("Allow ClipboardWarrior under Privacy & Security › Accessibility so it can press ⌘V for you.")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 5) {
            CWKeyCap(text: key)
            Text(label).font(.system(size: 10)).foregroundStyle(.tertiary)
        }
    }

    private func move(_ delta: Int, count: Int) {
        guard count > 0 else { return }
        selectedIndex = min(max(selectedIndex + delta, 0), count - 1)
    }
}

private struct QuickPasteRow: View {
    let item: ClipItem
    let index: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 11) {
            ClipLeadingIcon(item: item, size: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.preview)
                    .lineLimit(1)
                    .font(item.kind.isCode && !item.isSensitive
                          ? .system(size: 13, design: .monospaced) : .system(size: 13))
                    .foregroundStyle(item.isSensitive ? Color.secondary : Color.primary)
                HStack(spacing: 6) {
                    KindBadge(kind: item.kind)
                    if !item.sourceApp.isEmpty { Text(item.sourceApp).lineLimit(1) }
                    Text(item.lastCopiedAt, format: .relative(presentation: .numeric, unitsStyle: .abbreviated))
                        .layoutPriority(1)
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(CWStyle.accent)
            }
            if index < 9 { CWKeyCap(text: "⌘\(index + 1)") }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(isSelected ? CWStyle.accent.opacity(0.14) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .contentShape(Rectangle())
    }
}
