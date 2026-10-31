import AppKit
import ServiceManagement
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Settings

struct SettingsView: View {
    @Environment(ClipboardMonitor.self) private var monitor

    @AppStorage(Pref.retentionDays) private var retentionDays = 0
    @AppStorage(Pref.sensitiveMode) private var sensitiveMode = SensitiveMode.keepMasked.rawValue
    @AppStorage(Pref.sensitiveTTLHours) private var ttlHours = 24
    @AppStorage(Pref.respectConcealed) private var respectConcealed = true
    @AppStorage(Pref.captureImages) private var captureImages = true
    @AppStorage(Pref.playSound) private var playSound = false
    @AppStorage(Pref.ignoredApps) private var ignoredApps = Pref.defaultIgnoredApps
    @AppStorage(Pref.globalHotKey) private var globalHotKey = true
    @AppStorage(Pref.hotKeyStyle) private var hotKeyStyle = "commandShiftV"

    @AppStorage(Pref.autosave) private var autosave = true
    @AppStorage(Pref.autosaveFolder) private var autosaveFolder = Pref.defaultAutosavePath
    @AppStorage(Pref.autosaveBookmark) private var autosaveBookmark = Data()
    @AppStorage(Pref.autosaveMinChars) private var autosaveMinChars = 1
    @AppStorage(Pref.autosaveImages) private var autosaveImages = false
    @AppStorage(Pref.autosaveRealExt) private var autosaveRealExt = false

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var confirmClear = false
    @State private var confirmClearSensitive = false

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
                Toggle("Global clipboard history shortcut", isOn: $globalHotKey)
                    .onChange(of: globalHotKey) { _, enabled in
                        NotificationCenter.default.post(name: .clipboardWarriorHotKeyPreferenceChanged, object: enabled)
                    }
                Picker("History shortcut", selection: $hotKeyStyle) {
                    Text("⌘⇧V").tag("commandShiftV")
                    Text("⌃⌥V").tag("controlOptionV")
                }
                .disabled(!globalHotKey)
                .onChange(of: hotKeyStyle) { _, _ in
                    NotificationCenter.default.post(name: .clipboardWarriorHotKeyPreferenceChanged, object: nil)
                }
                Text("Press ⌘⇧V anywhere to open history. Select a clip to copy it back.")
                    .font(.caption).foregroundStyle(.secondary)
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
                    }
                    Stepper("Skip clips shorter than \(autosaveMinChars) characters",
                            value: $autosaveMinChars, in: 1...500)
                    Toggle("Also save images (PNG)", isOn: $autosaveImages)
                    Toggle("Use real extensions (.py, .sh, .html) instead of .txt", isOn: $autosaveRealExt)
                }
                .disabled(!autosave)

                Text("Saves to Desktop/ClipboardWarrior by default, or the folder you choose. Passwords and keys are never written to disk.")
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("Never capture from these apps (bundle IDs, one per line)")
                        .font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $ignoredApps)
                        .font(.system(.caption, design: .monospaced))
                        .frame(height: 80)
                }
            }

            Section("Data") {
                Button("Delete all unpinned clips…", role: .destructive) { confirmClear = true }
                Button("Delete all sensitive clips…", role: .destructive) { confirmClearSensitive = true }
            }
        }
        .formStyle(.grouped)
        .frame(width: 540, height: 780)
        .confirmationDialog("Delete all unpinned clips?", isPresented: $confirmClear) {
            Button("Delete", role: .destructive) { monitor.deleteAllUnpinned() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
        .confirmationDialog("Delete all sensitive clips?", isPresented: $confirmClearSensitive) {
            Button("Delete", role: .destructive) { monitor.deleteAllSensitive() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Pinned ones too. This can't be undone.")
        }
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
    }
}

// MARK: - Export

@MainActor
enum Exporter {

    /// One Markdown file. Sensitive clips are left out. Code fences grow so clips that
    /// contain ``` can't break the document.
    static func exportMarkdown(context: ModelContext) {
        NSApp.activate()
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "ClipboardWarrior-\(Date().fileStamp).md"
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let d = FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\.createdAt)])
        let items = (try? context.fetch(d)) ?? []
        var out = "# Clipboard Warrior Export\n\nGenerated: \(Date().formatted())\n"
        var omitted = 0

        for kind in ClipKind.allCases {
            let group = items.filter { $0.kind == kind && !$0.isSensitive }
            omitted += items.filter { $0.kind == kind && $0.isSensitive }.count
            guard !group.isEmpty else { continue }
            out += "\n## \(kind.title)\n"
            for item in group {
                out += "\n### \(item.createdAt.formatted(date: .abbreviated, time: .shortened))"
                out += item.sourceApp.isEmpty ? "\n" : " · \(item.sourceApp)\n"
                if !item.tags.isEmpty { out += "Tags: `\(item.tags)`\n" }
                switch kind {
                case .image:
                    out += "\n_Image omitted (\(item.preview))_\n"
                case .files:
                    out += "\n" + item.text.split(separator: "\n").map { "- `\($0)`" }.joined(separator: "\n") + "\n"
                default:
                    var fence = "```"
                    while item.text.contains(fence) { fence += "`" }
                    let lang = kind.isCode ? kind.fileExtension : ""
                    out += "\n\(fence)\(lang)\n\(item.text)\n\(fence)\n"
                }
            }
        }
        if omitted > 0 { out += "\n---\n\(omitted) sensitive clip(s) omitted.\n" }

        do {
            try out.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
