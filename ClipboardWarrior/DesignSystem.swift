import AppKit
import SwiftUI

/// Shared visual tokens for ClipboardWarrior surfaces and controls.
enum CWStyle {
    static let accent = Color(red: 0.86, green: 0.16, blue: 0.22)
    static let success = Color(red: 0.20, green: 0.68, blue: 0.43)
    static let warning = Color(red: 0.94, green: 0.61, blue: 0.20)
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let field = Color(nsColor: .controlBackgroundColor).opacity(0.82)
    static let separator = Color.primary.opacity(0.06)
    static let hover = Color.primary.opacity(0.06)
    static let subtleFill = Color.primary.opacity(0.045)
    static let hairline = Color.primary.opacity(0.08)
}

extension View {
    func cwCardSurface(cornerRadius: CGFloat = 12) -> some View {
        background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.8)
            }
    }
}

// MARK: - Colors & symbols

extension Color {
    /// Accepts "RRGGBB" with or without a leading "#". Falls back to system blue.
    init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0x007AFF
        self.init(.sRGB,
                  red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255,
                  opacity: 1)
    }
}

enum CWSymbol {
    /// Board symbol that older builds could have stored under a name that is not a real SF Symbol
    /// (the "Code" board used `code`, which does not exist).
    static let codeBoard = "chevron.left.forwardslash.chevron.right"

    /// Returns `name` if it is a real SF Symbol, otherwise a safe folder fallback.
    static func resolved(_ name: String) -> String {
        if name == "code" { return codeBoard }
        return NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil ? name : "folder"
    }
}

// MARK: - Source app icons

/// Looks up and caches the icon of the app a clip was copied from.
@MainActor
final class AppIconProvider {
    static let shared = AppIconProvider()

    private let cache = NSCache<NSString, NSImage>()
    private var unavailable = Set<String>()

    func icon(forBundleID bundleID: String) -> NSImage? {
        guard !bundleID.isEmpty else { return nil }
        if let hit = cache.object(forKey: bundleID as NSString) { return hit }
        if unavailable.contains(bundleID) { return nil }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            unavailable.insert(bundleID)
            return nil
        }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        image.size = NSSize(width: 64, height: 64)
        cache.setObject(image, forKey: bundleID as NSString)
        return image
    }
}

// MARK: - Confirmations

/// Native alerts for destructive actions.
///
/// SwiftUI's `confirmationDialog` attaches to the view's window. Inside the menu bar popover that
/// window resigns key the moment the prompt appears, so the dialog dismisses or can't be clicked.
/// An `NSAlert` is its own modal window and behaves the same from the popover, the archive window
/// and Settings.
@MainActor
enum Confirm {
    static func destructive(title: String,
                            message: String,
                            actionTitle: String,
                            perform: @escaping () -> Void) {
        // Let a SwiftUI Menu finish closing before the modal takes over.
        DispatchQueue.main.async {
            NSApp.activate()
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = title
            alert.informativeText = message
            alert.addButton(withTitle: "Cancel")                      // default (Return)
            let destructive = alert.addButton(withTitle: actionTitle)
            destructive.hasDestructiveAction = true
            if alert.runModal() == .alertSecondButtonReturn { perform() }
        }
    }

    static func inform(title: String, message: String) {
        DispatchQueue.main.async {
            NSApp.activate()
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = title
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

// MARK: - Small shared views

/// Capsule used for the filter row in the menu bar popover.
struct CWChip: View {
    let title: String
    let symbol: String
    var tint: Color = .secondary
    var isActive = false
    var showsChevron = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
            Text(title).lineLimit(1)
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
                    .opacity(0.7)
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(isActive ? tint : Color.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isActive ? tint.opacity(0.14) : CWStyle.subtleFill, in: Capsule())
        .overlay {
            Capsule().strokeBorder(isActive ? tint.opacity(0.28) : CWStyle.hairline, lineWidth: 0.8)
        }
        .contentShape(Capsule())
    }
}

/// Small keyboard-key style label, e.g. "⌘1".
struct CWKeyCap: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(CWStyle.subtleFill, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}
