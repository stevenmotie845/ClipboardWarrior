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
    @AppStorage(Pref.quickPasteHotKey) private var quickPasteHotKey = true
    @AppStorage(Pref.quickPasteStyle) private var quickPasteStyle = "controlCommandV"

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
                    }
                    Stepper("Skip clips shorter than \(autosaveMinChars) characters",
                            value: $autosaveMinChars, in: 1...500)
                    Toggle("Also save images (PNG)", isOn: $autosaveImages)
                    Toggle("Use real extensions (.py, .sh, .html) instead of .txt", isOn: $autosaveRealExt)
                }
                .disabled(!autosave)

                Text("Saves to ~/ClipboardWarrior by default, or the folder you choose. Passwords and keys are never written to disk.")
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
