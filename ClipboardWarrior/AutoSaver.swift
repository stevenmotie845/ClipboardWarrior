import AppKit
import Foundation

/// Writes clips to disk as  <root>/<Category>/<label>_<timestamp>.txt
/// Default root is inside the app container. Customer-selected folders use security-scoped bookmarks.
///
/// All of this is nonisolated and runs off the main thread; the monitor hands it plain value types.
nonisolated enum AutoSaver {

    /// Plain snapshot of a clip, safe to send to a background task.
    struct Job: Sendable {
        let kind: ClipKind
        let text: String
        let imageFileName: String
        let createdAt: Date
    }

    struct Config: Sendable {
        let root: URL
        let realExtensions: Bool
        /// Present only when a security-scoped bookmark resolved (needed if the app is sandboxed).
        let bookmarkData: Data?

        static func current() -> Config {
            let defaults = UserDefaults.standard
            let realExt = defaults.bool(forKey: Pref.autosaveRealExt)

            // The folder shown in Settings is always the one we write to.
            let path = defaults.string(forKey: Pref.autosaveFolder) ?? Pref.defaultAutosavePath
            let pathURL = URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)

            // A bookmark adds sandbox permission for that folder. If it can't be used, keep the
            // bookmark and fall back to the plain path: it works when the app isn't sandboxed,
            // and otherwise fails with a clear "choose the folder again" note.
            guard var bookmark = defaults.data(forKey: Pref.autosaveBookmark), !bookmark.isEmpty else {
                return Config(root: pathURL, realExtensions: realExt, bookmarkData: nil)
            }
            do {
                var isStale = false
                let root = try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope],
                                   relativeTo: nil, bookmarkDataIsStale: &isStale)
                if isStale {
                    let started = root.startAccessingSecurityScopedResource()
                    defer { if started { root.stopAccessingSecurityScopedResource() } }
                    if let fresh = try? root.bookmarkData(options: [.withSecurityScope],
                                                          includingResourceValuesForKeys: nil, relativeTo: nil) {
                        bookmark = fresh
                        defaults.set(fresh, forKey: Pref.autosaveBookmark)
                    }
                }
                return Config(root: root, realExtensions: realExt, bookmarkData: bookmark)
            } catch {
                return Config(root: pathURL, realExtensions: realExt, bookmarkData: nil)
            }
        }

        func beginAccess() throws -> Bool {
            guard bookmarkData != nil else { return false }
            guard root.startAccessingSecurityScopedResource() else {
                throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError)
            }
            return true
        }

        func endAccess(_ didStart: Bool) {
            if didStart { root.stopAccessingSecurityScopedResource() }
        }
    }

    /// Short clips are noise, and anything that looks like a credential never touches the disk.
    static func isWorthSaving(_ job: Job, minChars: Int) -> Bool {
        if job.kind == .image { return !job.imageFileName.isEmpty }
        if job.kind == .files { return false }
        let trimmed = job.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minChars else { return false }
        return SecretScanner.scan(job.text) == nil
    }

    /// Writes one clip. Safe to call twice for the same clip: identical content is skipped,
    /// different content with the same name gets a _2, _3 ... suffix.
    static func write(_ job: Job, config: Config) throws {
        let didStartAccess = try config.beginAccess()
        defer { config.endAccess(didStartAccess) }
        let fm = FileManager.default
        let dir = config.root.appendingPathComponent(job.kind.folderName, isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let ts = job.createdAt.fileStamp
        let isImage = job.kind == .image
        let stem = isImage ? "image_\(ts)" : "\(Helpers.slug(job.text))_\(ts)"
        let ext = isImage ? "png" : (config.realExtensions ? job.kind.fileExtension : "txt")

        let payload: Data
        if isImage {
            let src = ClipStore.imageURL(job.imageFileName)
            guard fm.fileExists(atPath: src.path) else { return }
            payload = try Data(contentsOf: src)
        } else {
            payload = Data(job.text.utf8)
        }

        var n = 1
        while true {
            let name = n == 1 ? "\(stem).\(ext)" : "\(stem)_\(n).\(ext)"
            let url = dir.appendingPathComponent(name)
            if !fm.fileExists(atPath: url.path) {
                try payload.write(to: url, options: .atomic)
                return
            }
            if (try? Data(contentsOf: url)) == payload { return }   // already saved
            n += 1
        }
    }

    /// True for "no permission" failures (sandbox or macOS Files & Folders privacy).
    static func isPermissionError(_ error: Error) -> Bool {
        let codes = [Int(EPERM), Int(EACCES)]
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain,
           [NSFileWriteNoPermissionError, NSFileReadNoPermissionError].contains(ns.code) { return true }
        if ns.domain == NSPOSIXErrorDomain, codes.contains(ns.code) { return true }
        if let u = ns.userInfo[NSUnderlyingErrorKey] as? NSError,
           u.domain == NSPOSIXErrorDomain, codes.contains(u.code) { return true }
        return false
    }

    static func failureNote(_ error: Error) -> String {
        isPermissionError(error)
            ? "Autosave blocked: choose the folder again in Settings to restore access."
            : "Autosave failed: \(error.localizedDescription)"
    }

    /// Opens the autosave folder in Finder, creating it if needed.
    @MainActor
    static func openFolder() {
        let config = Config.current()
        do {
            let didStartAccess = try config.beginAccess()
            defer { config.endAccess(didStartAccess) }
            try FileManager.default.createDirectory(at: config.root, withIntermediateDirectories: true)
            NSWorkspace.shared.open(config.root)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
