import AppKit
import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Pref.autosaveFolder) private var autosaveFolder = Pref.defaultAutosavePath
    @AppStorage(Pref.autosaveBookmark) private var autosaveBookmark = Data()
    @AppStorage(Pref.autosave) private var autosaveEnabled = true
    @AppStorage(Pref.autosaveImages) private var autosaveImages = false
    @AppStorage(Pref.onboardingComplete) private var onboardingComplete = false
    @State private var step = 0
    @State private var quickPasteAllowed = QuickPasteController.accessibilityGranted(prompt: false)
    @State private var folderError: String?

    private let steps = ["Welcome", "Storage", "Capture", "Ready"]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(steps.indices, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? CWStyle.accent : CWStyle.hairline)
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)

            Group {
                switch step {
                case 0: welcomePage
                case 1: storagePage
                case 2: capturePage
                default: readyPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(30)

            Divider()
            HStack {
                if step > 0 {
                    Button("Back") { withAnimation(.easeInOut(duration: 0.2)) { step -= 1 } }
                }
                Spacer()
                Button(step == steps.count - 1 ? "Start Using ClipboardWarrior" : "Continue") {
                    if step == steps.count - 1 { finish() }
                    else { withAnimation(.easeInOut(duration: 0.2)) { step += 1 } }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
        }
        .frame(width: 600, height: 560)
        .background(WindowFrontmostBridge())
        .onAppear { WindowActivation.activateAndRaiseKeyWindow() }
    }

    private var welcomePage: some View {
        VStack(spacing: 18) {
            Image("OnboardingHero")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 450, maxHeight: 180)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Text("Welcome to ClipboardWarrior")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("Your clipboard, organized.")
                .font(.title3.weight(.medium))
            Text("Keep a searchable history of what you copy, organize important clips into boards, pin favorites, and save useful snippets as files.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 430)
            HStack(spacing: 18) {
                feature("History", icon: "clock.arrow.circlepath")
                feature("Boards", icon: "square.grid.2x2")
                feature("Quick Paste", icon: "command")
            }
            .padding(.top, 8)
        }
    }

    private var storagePage: some View {
        VStack(alignment: .leading, spacing: 18) {
            pageHeading("Choose where clips are saved", subtitle: "Keep the default folder or choose a destination that works better for your workflow. You can change it later in Settings.")
            Toggle("Save new clips as files", isOn: $autosaveEnabled)
                .toggleStyle(.switch)
            VStack(alignment: .leading, spacing: 8) {
                Text("Local storage folder").font(.headline)
                HStack {
                    Image(systemName: "folder")
                        .foregroundStyle(CWStyle.accent)
                    Text((autosaveFolder as NSString).abbreviatingWithTildeInPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Choose…") { chooseFolder() }
                }
                .padding(12)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                Text("Default: ~/ClipboardWarrior. Autosaved clips are organized into category folders. Your selection is saved and can be changed at any time in Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Toggle("Save copied images as PNG files", isOn: $autosaveImages)
            if let folderError {
                Label(folderError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Spacer()
        }
    }

    private var capturePage: some View {
        VStack(alignment: .leading, spacing: 18) {
            pageHeading("Set up capture", subtitle: "Clipboard capture works through macOS pasteboard access. Quick Paste can also type the selected clip into the active app when Accessibility access is enabled.")
            Label("Clipboard history", systemImage: "checkmark.circle.fill")
                .foregroundStyle(CWStyle.success)
            Text("ClipboardWarrior will start recording new clipboard changes as soon as setup finishes. You can pause capture at any time from the menu bar.")
                .foregroundStyle(.secondary)
            Divider()
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: quickPasteAllowed ? "checkmark.shield.fill" : "hand.raised")
                    .font(.title2)
                    .foregroundStyle(quickPasteAllowed ? CWStyle.success : .secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick Paste Accessibility")
                        .font(.headline)
                    Text(quickPasteAllowed ? "Access is already enabled." : "Optional. Allows Quick Paste to send the paste keystroke for you.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !quickPasteAllowed {
                        Button("Open Accessibility Settings…") {
                            _ = QuickPasteController.accessibilityGranted(prompt: true)
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
                Spacer()
            }
            Spacer()
        }
    }

    private var readyPage: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 62))
                .foregroundStyle(CWStyle.success)
            Text("You're all set")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("Your preferences will be saved. You can revisit your storage folder, exclusions, and shortcuts from Settings whenever you need.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 420)
            VStack(alignment: .leading, spacing: 8) {
                Label("Storage: \((autosaveFolder as NSString).abbreviatingWithTildeInPath)", systemImage: "folder")
                Label(autosaveEnabled ? "Autosaver enabled" : "Autosaver paused", systemImage: "doc.text")
                Label("Clipboard history stays on this Mac", systemImage: "lock.laptopcomputer")
            }
            .font(.callout)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func feature(_ title: String, icon: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon).font(.title2).foregroundStyle(CWStyle.accent)
            Text(title).font(.caption.weight(.medium))
        }
    }

    private func pageHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 25, weight: .bold, design: .rounded))
            Text(subtitle).font(.callout).foregroundStyle(.secondary)
        }
    }

    private func chooseFolder() {
        NSApp.activate()
        let panel = NSOpenPanel()
        panel.title = "Choose ClipboardWarrior Storage Folder"
        panel.prompt = "Use Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: (autosaveFolder as NSString).expandingTildeInPath)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            autosaveFolder = url.path
            autosaveBookmark = (try? url.bookmarkData(options: [.withSecurityScope],
                                                       includingResourceValuesForKeys: nil, relativeTo: nil)) ?? Data()
            folderError = nil
            AppConfigurationStore.saveCurrentPreferences()
        } catch {
            folderError = error.localizedDescription
        }
    }

    private func finish() {
        onboardingComplete = true
        AppConfigurationStore.saveCurrentPreferences()
        dismiss()
    }
}
