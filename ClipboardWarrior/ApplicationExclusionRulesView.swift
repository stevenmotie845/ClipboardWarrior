import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Friendly editor for the existing bundle-ID exclusion preference. The stored format
/// remains backward-compatible with earlier versions (one bundle ID per line).
struct ApplicationExclusionRulesView: View {
    @AppStorage(Pref.ignoredApps) private var ignoredApps = Pref.defaultIgnoredApps
    @State private var manualBundleID = ""
    @State private var notice: String?

    private var rules: [String] {
        Array(Set(ignoredApps
            .split(whereSeparator: { $0 == "\n" || $0 == "," || $0 == " " })
            .map(String.init)
            .filter { !$0.isEmpty })).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Excluded applications")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    chooseApplication()
                } label: {
                    Label("Add App…", systemImage: "plus")
                }
            }

            if rules.isEmpty {
                ContentUnavailableView("No excluded apps", systemImage: "app.badge.checkmark",
                                       description: Text("ClipboardWarrior will capture clips from any foreground app."))
                    .frame(minHeight: 88)
            } else {
                VStack(spacing: 0) {
                    ForEach(rules, id: \.self) { bundleID in
                        HStack(spacing: 10) {
                            Image(systemName: "app")
                                .foregroundStyle(.secondary)
                                .frame(width: 18)
                            Text(displayName(for: bundleID))
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text(bundleID)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                            Button(role: .destructive) {
                                remove(bundleID)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                            .help("Remove exclusion")
                        }
                        .padding(.vertical, 6)
                        if bundleID != rules.last { Divider() }
                    }
                }
                .padding(.horizontal, 10)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                TextField("Add bundle ID manually", text: $manualBundleID)
                    .textFieldStyle(.roundedBorder)
                Button("Add") { addManualRule() }
                    .disabled(manualBundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Text(notice ?? "Excluded apps are never read by the clipboard monitor. Password managers are excluded by default.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func chooseApplication() {
        NSApp.activate()
        let panel = NSOpenPanel()
        panel.title = "Choose an Application to Exclude"
        panel.prompt = "Exclude App"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.applicationBundle]
        guard panel.runModal() == .OK else { return }

        let identifiers = panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
        guard !identifiers.isEmpty else {
            notice = "Couldn't read a bundle identifier from that app."
            return
        }
        var all = Set(rules)
        all.formUnion(identifiers)
        ignoredApps = all.sorted().joined(separator: "\n")
        notice = "Added \(identifiers.count) application rule(s)."
    }

    private func addManualRule() {
        let value = manualBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        var all = Set(rules)
        all.insert(value)
        ignoredApps = all.sorted().joined(separator: "\n")
        manualBundleID = ""
    }

    private func remove(_ bundleID: String) {
        ignoredApps = rules.filter { $0 != bundleID }.joined(separator: "\n")
    }

    private func displayName(for bundleID: String) -> String {
        switch bundleID {
        case "com.1password.1password", "com.agilebits.onepassword7": return "1Password"
        case "com.bitwarden.desktop": return "Bitwarden"
        case "com.apple.keychainaccess": return "Keychain Access"
        case "com.apple.Passwords": return "Passwords"
        default: return bundleID
        }
    }
}
