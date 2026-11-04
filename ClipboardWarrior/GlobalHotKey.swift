import AppKit
import Carbon

extension Notification.Name {
    static let clipboardWarriorShowArchive = Notification.Name("ClipboardWarriorShowArchive")
    static let clipboardWarriorQuickPaste = Notification.Name("ClipboardWarriorQuickPaste")
    static let clipboardWarriorHotKeyPreferenceChanged = Notification.Name("ClipboardWarriorHotKeyPreferenceChanged")
}

/// Registers the system-wide shortcuts:
///  - History shortcut (⌘⇧V or ⌃⌥V): opens the clipboard archive.
///  - Quick Paste shortcut (⌃⌘V, ⌥⇧V or ⌃⇧V): opens a floating picker that pastes the chosen clip
///    straight into the app you were using.
@MainActor
final class GlobalHotKey {
    private enum Slot: UInt32 {
        case history = 1
        case quickPaste = 2
    }

    private var hotKeys: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?

    init() {
        NotificationCenter.default.addObserver(
            forName: .clipboardWarriorHotKeyPreferenceChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.start()
            }
        }
    }

    /// (Re)registers whichever shortcuts are enabled in Settings.
    func start() {
        stop()
        let defaults = UserDefaults.standard
        let historyEnabled = defaults.bool(forKey: Pref.globalHotKey)
        let quickPasteEnabled = defaults.bool(forKey: Pref.quickPasteHotKey)
        guard historyEnabled || quickPasteEnabled else { return }

        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerProcPtr = { _, event, _ in
            var identifier = EventHotKeyID()
            let status = GetEventParameter(event,
                                           EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID),
                                           nil,
                                           MemoryLayout<EventHotKeyID>.size,
                                           nil,
                                           &identifier)
            guard status == noErr else { return status }
            let id = identifier.id
            DispatchQueue.main.async {
                let name: Notification.Name = (id == 2) ? .clipboardWarriorQuickPaste : .clipboardWarriorShowArchive
                NotificationCenter.default.post(name: name, object: nil)
            }
            return noErr
        }
        InstallEventHandler(GetEventDispatcherTarget(), callback, 1, &type, nil, &eventHandler)

        if historyEnabled {
            let alternate = defaults.string(forKey: Pref.hotKeyStyle) == "controlOptionV"
            register(modifiers: alternate ? (controlKey | optionKey) : (cmdKey | shiftKey), slot: .history)
        }
        if quickPasteEnabled {
            let modifiers: Int
            switch defaults.string(forKey: Pref.quickPasteStyle) {
            case "optionShiftV": modifiers = optionKey | shiftKey
            case "controlShiftV": modifiers = controlKey | shiftKey
            default: modifiers = controlKey | cmdKey
            }
            register(modifiers: modifiers, slot: .quickPaste)
        }
    }

    func stop() {
        for hotKey in hotKeys { UnregisterEventHotKey(hotKey) }
        hotKeys.removeAll()
        if let eventHandler { RemoveEventHandler(eventHandler); self.eventHandler = nil }
    }

    private func register(modifiers: Int, slot: Slot) {
        var reference: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: OSType(0x43505752), id: slot.rawValue)
        let status = RegisterEventHotKey(UInt32(kVK_ANSI_V), UInt32(modifiers), identifier,
                                         GetEventDispatcherTarget(), 0, &reference)
        if status == noErr, let reference { hotKeys.append(reference) }
    }
}
