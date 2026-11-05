import AppKit
import ServiceManagement
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Settings

struct SettingsView: View {
    @Environment(ClipboardMonitor.self) private var monitor
    @Environment(\.modelContext) private var modelContext

    @AppStorage(Pref.retentionDays) private var retentionDays = 0
    @AppStorage(Pref.sensitiveMode) private var sensitiveMode = SensitiveMode.keepMasked.rawValue
    @AppStorage(Pref.sensitiveTTLHours) private var ttlHours = 24
    @AppStorage(Pref.respectConcealed) private var respectConcealed = true
    @AppStorage(Pref.captureImages) private var captureImages = true
    @AppStorage(Pref.playSound) private var playSound = false
    @AppStorage(Pref.globalHotKey) private var globalHotKey = true
    @AppStorage(Pref.hotKeyStyle) private var hotKeyStyle = "commandShiftV"
    @AppStorage(Pref.quickPasteHotKey) private var quickPasteHotKey = true
    @AppStorage(Pref.quickPasteStyle) private var quickPasteStyle = "controlCommandV"
    @AppStorage(Pref.hotKeyRegistrationWarning) private var hotKeyRegistrationWarning = ""

    @AppStorage(Pref.autosave) private var autosave = true
    @AppStorage(Pref.autosaveFolder) private var autosaveFolder = Pref.defaultAutosavePath
    @AppStorage(Pref.autosaveBookmark) private var autosaveBookmark = Data()
    @AppStorage(Pref.autosaveMinChars) private var autosaveMinChars = 1
    @AppStorage(Pref.autosaveImages) private var autosaveImages = false
    @AppStorage(Pref.autosaveRealExt) private var autosaveRealExt = false

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var autoPasteAllowed = QuickPasteController.accessibilityGranted(prompt: false)

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        do {
                            if on { try SMAppService.mainApp.register() }
                            else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                Toggle("Play a sound when a clip is saved", isOn: $playSound)
                Toggle("Capture images", isOn: $captureImages)
            }

            Section("Shortcuts") {
                Toggle("Open history with a global shortcut", isOn: $globalHotKey)
                    .onChange(of: globalHotKey) { _, _ in
                        NotificationCenter.default.post(name: .clipboardWarriorHotKeyPreferenceChanged, object: nil)
                    }
                Picker("History shortcut", selection: $hotKeyStyle) {
                    Text("⌘⇧V").tag("commandShiftV")
                    Text("⌃⌥V").tag("controlOptionV")
                }
                .disabled(!globalHotKey)
                .onChange(of: hotKeyStyle) { _, _ in
                    NotificationCenter.default.post(name: .clipboardWarriorHotKeyPreferenceChanged, object: nil)
                }

                Toggle("Quick Paste shortcut", isOn: $quickPasteHotKey)
                    .onChange(of: quickPasteHotKey) { _, _ in
                        NotificationCenter.default.post(name: .clipboardWarriorHotKeyPreferenceChanged, object: nil)
                    }
                Picker("Quick Paste keys", selection: $quickPasteStyle) {
                    Text("⌃⌘V").tag("controlCommandV")
                    Text("⌥⇧V").tag("optionShiftV")
                    Text("⌃⇧V").tag("controlShiftV")
                }
                .disabled(!quickPasteHotKey)
                .onChange(of: quickPasteStyle) { _, _ in
                    NotificationCenter.default.post(name: .clipboardWarriorHotKeyPreferenceChanged, object: nil)
                }
                Text("The history shortcut opens the archive. Quick Paste opens a small picker over whatever you’re working in; choose a clip and it is pasted straight into that app.")
                    .font(.caption).foregroundStyle(.secondary)
                if !hotKeyRegistrationWarning.isEmpty {
                    Label(hotKeyRegistrationWarning, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                LabeledContent("Auto-paste access") {
                    if autoPasteAllowed {
                        Label("Allowed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(CWStyle.success)
                    } else {
                        Button("Allow in System Settings…") {
                            _ = QuickPasteController.accessibilityGranted(prompt: true)
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
                if !autoPasteAllowed {
                    Text("Quick Paste presses ⌘V for you, which macOS only allows once ClipboardWarrior is listed under Privacy & Security › Accessibility. Until then it copies the clip and you paste it yourself.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Autosave to folder") {
                Toggle("Save new clips as files", isOn: $autosave)

                Group {
                    LabeledContent("Folder") {
                        Text((autosaveFolder as NSString).abbreviatingWithTildeInPath)
                            .lineLimit(1)
                            .truncationMode(.head)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Button("Choose…") { chooseFolder() }
                        Button("Show in Finder") { AutoSaver.openFolder() }
                        Button("Save existing clips now") { monitor.syncAllToFolder() }
                            .disabled(!autosave)
                    }
                    Stepper("Skip clips shorter than \(autosaveMinChars) characters",
                            value: $autosaveMinChars, in: 1...500)
                        .disabled(!autosave)
                    Toggle("Also save images (PNG)", isOn: $autosaveImages)
                        .disabled(!autosave)
                    Toggle("Use real extensions (.py, .sh, .html) instead of .txt", isOn: $autosaveRealExt)
                        .disabled(!autosave)
                }

                Text("Saves to ~/ClipboardWarrior by default, or the folder you choose. You can change this destination at any time. Passwords and keys are never written to disk.")
                    .font(.caption).foregroundStyle(.secondary)
            }


            Section("History") {
                Text("Clips stay in your history until you delete them. The archive comfortably handles 1,000 or more captures.")
                    .font(.caption).foregroundStyle(.secondary)
                Picker("Delete unpinned clips after", selection: $retentionDays) {
                    Text("Never").tag(0)
                    Text("1 day").tag(1)
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                }
                Text("Pinned clips are never deleted automatically. Autosaved files are never deleted by the app.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Passwords & secrets") {
                Toggle("Ignore clips marked concealed by password managers", isOn: $respectConcealed)
                Picker("When a clip looks sensitive", selection: $sensitiveMode) {
                    ForEach(SensitiveMode.allCases) { Text($0.title).tag($0.rawValue) }
                }
                if sensitiveMode == SensitiveMode.maskAndExpire.rawValue {
                    Stepper("Auto-delete after \(ttlHours) hour\(ttlHours == 1 ? "" : "s")",
                            value: $ttlHours, in: 1...720)
                }
            }

            Section("Application exclusions") {
                ApplicationExclusionRulesView()
            }

            Section("Backup & Restore") {
                HStack(spacing: 10) {
                    Image(systemName: "externaldrive.badge.timemachine")
                        .font(.title2)
                        .foregroundStyle(CWStyle.accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Keep a portable copy of your library")
                            .font(.headline)
                        Text("Backups include clips, boards, metadata, and saved images. Backup files are not encrypted.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Button("Create Backup…") { BackupRestoreManager.exportBackup(context: modelContext) }
                Button("Restore from Backup…") { BackupRestoreManager.importBackup(context: modelContext) }
            }

            Section("Data") {
                Button("Delete all clips…", role: .destructive) { monitor.confirmDeleteAllClips() }
                Button("Clear pinned clips…", role: .destructive) { monitor.confirmDeletePinnedClips() }
                Button("Delete all sensitive clips…", role: .destructive) { monitor.confirmDeleteSensitiveClips() }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560)
        .frame(minHeight: 480, idealHeight: 760)
        .background(WindowFrontmostBridge())
        .onAppear {
            WindowActivation.activateAndRaiseKeyWindow()
            autoPasteAllowed = QuickPasteController.accessibilityGranted(prompt: false)
        }
        .onChange(of: autosave) { _, _ in AppConfigurationStore.saveCurrentPreferences() }
        .onChange(of: autosaveImages) { _, _ in AppConfigurationStore.saveCurrentPreferences() }
    }

    private func chooseFolder() {
        NSApp.activate()
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Use Folder"
        panel.directoryURL = URL(fileURLWithPath: (autosaveFolder as NSString).expandingTildeInPath)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        autosaveFolder = url.path
        // The bookmark only matters if the app is sandboxed; the path alone is enough otherwise.
        autosaveBookmark = (try? url.bookmarkData(options: [.withSecurityScope],
                                                  includingResourceValuesForKeys: nil, relativeTo: nil)) ?? Data()
        AppConfigurationStore.saveCurrentPreferences()
    }
}

// MARK: - Export

@MainActor
enum Exporter {
    static func exportIndividualMarkdown(context: ModelContext) {
        NSApp.activate()
        let panel = NSOpenPanel()
        panel.title = "Choose a folder for exported Markdown clips"
        panel.prompt = "Export Here"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let folder = panel.url else { return }

        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let items = try context.fetch(FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\.createdAt)]))
            var exported = 0
            var omitted = 0
            for item in items {
                guard !item.isSensitive else { omitted += 1; continue }
                let filename = individualFilename(for: item)
                let destination = folder.appendingPathComponent(filename, isDirectory: false)
                let imageReference = try exportImageIfNeeded(for: item, into: folder, imageDirectoryName: "Images")
                try markdown(for: item, imageReference: imageReference)
                    .write(to: destination, atomically: true, encoding: .utf8)
                exported += 1
            }
            let alert = NSAlert()
            alert.messageText = "Markdown export complete"
            alert.informativeText = "Exported \(exported) clip(s) to \(folder.path).\(omitted > 0 ? "\n\(omitted) sensitive clip(s) were omitted." : "")"
            alert.runModal()
            NSWorkspace.shared.activateFileViewerSelecting([folder])
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    /// Exports the full archive to one Markdown document. Sensitive clips are omitted.
    static func exportMarkdown(context: ModelContext) {
        NSApp.activate()
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "ClipboardWarrior-Archive-\(Date().fileStamp).md"
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let items = try context.fetch(FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\.createdAt)]))
            let safeItems = items.filter { !$0.isSensitive }
            let omitted = items.count - safeItems.count
            var out = "# ClipboardWarrior Archive\n\nGenerated: \(Date().formatted())\n"
            let imageFolderName = url.deletingPathExtension().lastPathComponent + "-Images"
            for kind in ClipKind.allCases {
                let group = safeItems.filter { $0.kind == kind }
                guard !group.isEmpty else { continue }
                out += "\n## \(kind.title)\n"
                for item in group {
                    let imageReference = try exportImageIfNeeded(
                        for: item, into: url.deletingLastPathComponent(), imageDirectoryName: imageFolderName)
                    out += "\n" + markdown(for: item, includeHeading: true, imageReference: imageReference) + "\n"
                }
            }
            if omitted > 0 { out += "\n---\n\(omitted) sensitive clip(s) omitted.\n" }
            try out.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private static func markdown(for item: ClipItem, includeHeading: Bool = false,
                                 imageReference: String? = nil) -> String {
        var out = ""
        if includeHeading {
            out += "### \(item.createdAt.formatted(date: .abbreviated, time: .shortened))"
            if !item.sourceApp.isEmpty { out += " · \(item.sourceApp)" }
            out += "\n"
        } else {
            out += "# \(item.kind.title) Clip\n\n"
            out += "- Captured: \(item.createdAt.formatted())\n"
            if !item.sourceApp.isEmpty { out += "- Source app: \(item.sourceApp)\n" }
            if !item.tags.isEmpty { out += "- Tags: \(item.tags)\n" }
            out += "- Type: \(item.kind.title)\n\n"
        }
        if !item.tags.isEmpty, includeHeading { out += "Tags: `\(item.tags)`\n" }
        switch item.kind {
        case .image:
            if let imageReference {
                out += "\n![Clipboard image](\(imageReference))\n"
                if !item.preview.isEmpty { out += "\n_\(item.preview)_\n" }
            } else {
                out += "\n_Image file isn't available (\(item.preview))._\n"
            }
        case .files:
            out += "\n" + item.text.split(separator: "\n").map { "- `\($0)`" }.joined(separator: "\n") + "\n"
        default:
            var fence = "```"
            while item.text.contains(fence) { fence += "`" }
            let language = item.kind.isCode ? item.kind.fileExtension : ""
            out += "\n\(fence)\(language)\n\(item.text)\n\(fence)\n"
        }
        return out
    }

    private static func exportImageIfNeeded(for item: ClipItem, into exportRoot: URL,
                                            imageDirectoryName: String) throws -> String? {
        guard item.kind == .image, !item.imageFileName.isEmpty else { return nil }
        let source = ClipStore.imageURL(item.imageFileName)
        guard FileManager.default.fileExists(atPath: source.path) else { return nil }
        try FileManager.default.createDirectory(at: exportRoot, withIntermediateDirectories: true)
        let imagesDirectory = exportRoot.appendingPathComponent(imageDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        let destinationName = item.contentHash + ".png"
        let destination = imagesDirectory.appendingPathComponent(destinationName)
        if !FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.copyItem(at: source, to: destination)
        }
        return "\(imageDirectoryName)/\(destinationName)"
    }

    private static func individualFilename(for item: ClipItem) -> String {
        let date = item.createdAt.formatted(.iso8601)
            .replacingOccurrences(of: ":", with: "-")
        let preview = item.preview
            .components(separatedBy: .newlines).joined(separator: " ")
            .replacingOccurrences(of: "[^A-Za-z0-9_-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let shortPreview = String(preview.prefix(42))
        let suffix = String(item.contentHash.prefix(8))
        return "\(date)-\(item.kind.rawValue)-\(shortPreview.isEmpty ? "clip" : shortPreview)-\(suffix).md"
    }
}
