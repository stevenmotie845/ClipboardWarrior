import AppKit
import Carbon

extension Notification.Name {
    static let clipboardWarriorShowArchive = Notification.Name("ClipboardWarriorShowArchive")
    static let clipboardWarriorHotKeyPreferenceChanged = Notification.Name("ClipboardWarriorHotKeyPreferenceChanged")
}

/// Registers the selected system-wide shortcut used to open clipboard history.
@MainActor
final class GlobalHotKey {
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    init() {
        NotificationCenter.default.addObserver(
            forName: .clipboardWarriorHotKeyPreferenceChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.start(enabled: UserDefaults.standard.bool(forKey: Pref.globalHotKey))
            }
        }
    }

    func start(enabled: Bool) {
        stop()
        guard enabled else { return }

        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerProcPtr = { _, _, _ in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .clipboardWarriorShowArchive, object: nil)
            }
            return noErr
        }
        InstallEventHandler(GetEventDispatcherTarget(), callback, 1, &type, nil, &eventHandler)

        let alternate = UserDefaults.standard.string(forKey: Pref.hotKeyStyle) == "controlOptionV"
        let modifiers = alternate ? (controlKey | optionKey) : (cmdKey | shiftKey)
        let identifier = EventHotKeyID(signature: OSType(0x43505752), id: 1)
        RegisterEventHotKey(UInt32(kVK_ANSI_V), UInt32(modifiers), identifier,
                            GetEventDispatcherTarget(), 0, &hotKey)
    }

    func stop() {
        if let hotKey { UnregisterEventHotKey(hotKey); self.hotKey = nil }
        if let eventHandler { RemoveEventHandler(eventHandler); self.eventHandler = nil }
    }

}
