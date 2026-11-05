import AppKit
import CryptoKit
import Foundation

// MARK: - Preferences

nonisolated enum Pref {
    static let retentionDays = "retentionDays"
    static let sensitiveMode = "sensitiveMode"
    static let sensitiveTTLHours = "sensitiveTTLHours"
    static let respectConcealed = "respectConcealed"
    static let captureImages = "captureImages"
    static let playSound = "playSound"
    static let ignoredApps = "ignoredApps"
    static let globalHotKey = "globalHotKey"
    static let hotKeyStyle = "hotKeyStyle"
    static let quickPasteHotKey = "quickPasteHotKey"
    static let quickPasteStyle = "quickPasteStyle"

    static let autosave = "autosave"
    static let autosaveFolder = "autosaveFolder"
    static let autosaveBookmark = "autosaveBookmark"
    static let autosaveMinChars = "autosaveMinChars"
    static let autosaveImages = "autosaveImages"
    static let autosaveRealExt = "autosaveRealExt"
    static let onboardingComplete = "onboardingComplete"

    static let defaultIgnoredApps = [
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.bitwarden.desktop",
        "com.apple.keychainaccess",
        "com.apple.Passwords",
    ].joined(separator: "\n")

    /// The user's real home folder, even if the app happens to be sandboxed.
    static var realHome: String {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir { return String(cString: dir) }
        return NSHomeDirectory()
    }

    /// Default autosave location: ~/ClipboardWarrior.
    static var defaultAutosavePath: String {
        (realHome as NSString).appendingPathComponent("ClipboardWarrior")
    }

    static func register() {
        let d = UserDefaults.standard
        let oldDesktopDefault = (realHome as NSString).appendingPathComponent("Desktop/ClipboardWarrior")
        let storedFolder = Bundle.main.bundleIdentifier.flatMap { bundleID in
            d.persistentDomain(forName: bundleID)?[autosaveFolder] as? String
        }
        // Migrate only the exact former default; preserve any explicitly chosen custom folder.
        if let storedFolder,
           (storedFolder as NSString).standardizingPath == (oldDesktopDefault as NSString).standardizingPath {
            d.set(defaultAutosavePath, forKey: autosaveFolder)
            d.removeObject(forKey: autosaveBookmark)
        }
        UserDefaults.standard.register(defaults: [
            retentionDays: 0,                       // 0 = keep forever
            sensitiveMode: SensitiveMode.keepMasked.rawValue,
            sensitiveTTLHours: 24,
            respectConcealed: true,
            captureImages: true,
            playSound: false,
            ignoredApps: defaultIgnoredApps,
            globalHotKey: true,
            hotKeyStyle: "commandShiftV",
            quickPasteHotKey: true,
            quickPasteStyle: "controlCommandV",
            autosave: true,
            autosaveFolder: defaultAutosavePath,
            autosaveMinChars: 1,
            autosaveImages: false,
            autosaveRealExt: false,
            onboardingComplete: false,
        ])
    }
}

/// What to do when a clip looks like a password / token / key / card number.
nonisolated enum SensitiveMode: String, CaseIterable, Identifiable {
    case saveNormally
    case keepMasked
    case maskAndExpire
    case skip

    var id: String { rawValue }

    var title: String {
        switch self {
        case .saveNormally: "Save like any other clip"
        case .keepMasked: "Save, but mask in the UI"
        case .maskAndExpire: "Save, mask, and auto-delete"
        case .skip: "Don't save"
        }
    }
}

// MARK: - Store paths

nonisolated enum ClipStore {
    // Folder name kept as "ClipArchive" so images from earlier builds keep loading.
    static var imagesDirectory: URL {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClipArchive/Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func imageURL(_ fileName: String) -> URL {
        imagesDirectory.appendingPathComponent(fileName)
    }
}

// MARK: - Helpers

enum Helpers {
    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Single-line preview for list rows.
    static func preview(text: String, kind: ClipKind, byteSize: Int) -> String {
        switch kind {
        case .image:
            return "Image · " + ByteCountFormatter.string(fromByteCount: Int64(byteSize), countStyle: .file)
        case .files:
            let names = text.split(separator: "\n").map { URL(fileURLWithPath: String($0)).lastPathComponent }
            return names.prefix(4).joined(separator: ", ") + (names.count > 4 ? " +\(names.count - 4) more" : "")
        default:
            let head = String(text.prefix(300))
            return head.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        }
    }

    /// First non-empty line -> safe filename stem.
    nonisolated static func slug(_ text: String, maxLength: Int = 38) -> String {
        let first = text.split(separator: "\n").first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let line = first.map(String.init) ?? ""
        let cleaned = line.unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) || $0 == "-" ? Character($0) : " " }
        let joined = String(String(cleaned)
            .split(separator: " ")
            .joined(separator: "_")
            .prefix(maxLength))
        return joined.isEmpty ? "clip" : joined
    }

    private static let tagRegex = try! NSRegularExpression(
        pattern: "(?<![\\w&#/])#([A-Za-z][A-Za-z0-9_-]{1,24})\\b"
    )

    /// #hashtags from prose only. Skips code (`#include`, `#!/bin/sh`) and hex colors (`#fff`, `#a1b2c3`).
    static func tags(in text: String, kind: ClipKind) -> String {
        guard !kind.isCode, kind != .image, kind != .files, kind != .url else { return "" }
        let sample = String(text.prefix(20_000))
        let ns = sample as NSString
        var seen: [String] = []
        for m in tagRegex.matches(in: sample, range: NSRange(location: 0, length: ns.length)) {
            let tag = ns.substring(with: m.range(at: 1))
            let isHex = [3, 6, 8].contains(tag.count) && tag.allSatisfy(\.isHexDigit)
            if !isHex, !seen.contains(tag.lowercased()) { seen.append(tag.lowercased()) }
        }
        return seen.joined(separator: ",")
    }
}

extension Date {
    /// yyyyMMdd_HHmmss, used in exported / autosaved file names. Safe to call from any thread.
    nonisolated var fileStamp: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f.string(from: self)
    }
}

extension NSImage {
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
