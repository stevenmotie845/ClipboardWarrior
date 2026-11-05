import Foundation

/// Persists setup choices outside the autosave folder so the configuration remains
/// available even when a user moves or disconnects their selected destination.
nonisolated enum AppConfigurationStore {
    struct Configuration: Codable {
        var version: Int = 1
        var autosaveFolder: String
        var autosaveEnabled: Bool
        var autosaveImages: Bool
        var onboardingCompleted: Bool
        var updatedAt: Date = Date()
    }

    static var configurationURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClipboardWarrior", isDirectory: true)
            .appendingPathComponent("configuration.json", isDirectory: false)
    }

    static func saveCurrentPreferences() {
        let defaults = UserDefaults.standard
        let config = Configuration(
            autosaveFolder: defaults.string(forKey: Pref.autosaveFolder) ?? Pref.defaultAutosavePath,
            autosaveEnabled: defaults.object(forKey: Pref.autosave) as? Bool ?? true,
            autosaveImages: defaults.bool(forKey: Pref.autosaveImages),
            onboardingCompleted: defaults.bool(forKey: Pref.onboardingComplete)
        )
        do {
            let directory = configurationURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(config).write(to: configurationURL, options: .atomic)
        } catch {
            NSLog("ClipboardWarrior couldn't save its configuration: %@", error.localizedDescription)
        }
    }

    static func load() -> Configuration? {
        guard let data = try? Data(contentsOf: configurationURL) else { return nil }
        return try? JSONDecoder().decode(Configuration.self, from: data)
    }
}
