import AppKit
import Carbon

extension Notification.Name {
    static let clipboardWarriorShowArchive = Notification.Name("ClipboardWarriorShowArchive")
    static let clipboardWarriorQuickPaste = Notification.Name("ClipboardWarriorQuickPaste")
    static let clipboardWarriorHotKeyPreferenceChanged = Notification.Name("ClipboardWarriorHotKeyPreferenceChanged")
}

/// Registers the system-wide shortcuts:
///  - History shortcut (⌘⇧V or ⌃⌥V): opens the clipboard archive.
///  - Quick Paste shortcut (⌃⌘V, ⌥⇧V or ⌃⇧V): opens a floating picker.
///
/// The preference observer uses the selector-based NotificationCenter API. This avoids
/// capturing an actor-isolated `self` inside a concurrently-executing observer closure.
@MainActor
final class GlobalHotKey: NSObject {
    private enum Slot: UInt32 {
        case history = 1
        case quickPaste = 2
    }

    private var hotKeys: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotKeyPreferencesChanged(_:)),
            name: .clipboardWarriorHotKeyPreferenceChanged,
            object: nil
        )
    }

    @objc private func hotKeyPreferencesChanged(_ notification: Notification) {
        start()
    }

    /// Re-registers the shortcuts currently enabled in Settings.
    func start() {
        stop()
        UserDefaults.standard.removeObject(forKey: Pref.hotKeyRegistrationWarning)

        let defaults = UserDefaults.standard
        let historyEnabled = defaults.bool(forKey: Pref.globalHotKey)
        let quickPasteEnabled = defaults.bool(forKey: Pref.quickPasteHotKey)
        guard historyEnabled || quickPasteEnabled else { return }

        var type = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let callback: EventHandlerProcPtr = { _, event, _ in
            var identifier = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &identifier
            )
            guard status == noErr else { return status }

            let hotKeyID = identifier.id
            guard hotKeyID == 1 || hotKeyID == 2 else { return noErr }
            DispatchQueue.main.async {
                let name: Notification.Name = hotKeyID == 2
                    ? .clipboardWarriorQuickPaste
                    : .clipboardWarriorShowArchive
                NotificationCenter.default.post(name: name, object: nil)
            }
            return noErr
        }

        var installedHandler: EventHandlerRef?
        let installStatus = InstallEventHandler(
            GetEventDispatcherTarget(), callback, 1, &type, nil, &installedHandler
        )
        guard installStatus == noErr, let installedHandler else {
            setWarning("Keyboard shortcuts could not be initialized (Carbon error \(installStatus)).")
            return
        }
        eventHandler = installedHandler

        let historyModifiers: Int? = historyEnabled
            ? (defaults.string(forKey: Pref.hotKeyStyle) == "controlOptionV"
                ? (controlKey | optionKey) : (cmdKey | shiftKey))
            : nil

        let quickPasteModifiers: Int? = quickPasteEnabled
            ? quickPasteModifier(from: defaults.string(forKey: Pref.quickPasteStyle))
            : nil

        if let historyModifiers {
            register(modifiers: historyModifiers, slot: .history)
        }

        if let quickPasteModifiers {
            if historyModifiers == quickPasteModifiers {
                setWarning("History and Quick Paste are assigned the same shortcut. Change one in Settings.")
            } else {
                register(modifiers: quickPasteModifiers, slot: .quickPaste)
            }
        }

        if hotKeys.isEmpty {
            if UserDefaults.standard.string(forKey: Pref.hotKeyRegistrationWarning) == nil {
                setWarning("macOS did not allow the selected keyboard shortcut to be registered. Try another combination.")
            }
            if let eventHandler {
                RemoveEventHandler(eventHandler)
                self.eventHandler = nil
            }
        }
    }

    func stop() {
        for hotKey in hotKeys {
            UnregisterEventHotKey(hotKey)
        }
        hotKeys.removeAll()

        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private func quickPasteModifier(from style: String?) -> Int {
        switch style {
        case "optionShiftV": optionKey | shiftKey
        case "controlShiftV": controlKey | shiftKey
        default: controlKey | cmdKey
        }
    }

    private func register(modifiers: Int, slot: Slot) {
        var reference: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: OSType(0x43505752), id: slot.rawValue)
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_V), UInt32(modifiers), identifier,
            GetEventDispatcherTarget(), 0, &reference
        )
        if status == noErr, let reference {
            hotKeys.append(reference)
        } else {
            let shortcut = slot == .history ? "History" : "Quick Paste"
            setWarning("\(shortcut) shortcut could not be registered (Carbon error \(status)). Try another combination.")
        }
    }

    private func setWarning(_ message: String) {
        UserDefaults.standard.set(message, forKey: Pref.hotKeyRegistrationWarning)
    }
}
