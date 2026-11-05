# ClipboardWarrior project update notes

## Added Swift source files

- `AppConfigurationStore.swift` — writes persistent JSON configuration to `~/Library/Application Support/ClipboardWarrior/configuration.json`.
- `ApplicationExclusionRulesView.swift` — lets users add installed apps or bundle IDs to the existing clipboard exclusion list and remove rules.
- `OnboardingView.swift` — first-launch setup for the local folder, Autosaver, and Quick Paste accessibility.

The project uses an Xcode file-system-synchronized source group, so these Swift files are automatically part of the app target.

## Preserved storage settings

The Autosaver destination remains configurable. It defaults to `~/ClipboardWarrior`, can be chosen during onboarding, and can be changed later in Settings. The selected folder and relevant preferences are also persisted to a JSON configuration file in Application Support. Existing custom folder paths are preserved; only the exact previous `~/Desktop/ClipboardWarrior` default is migrated to `~/ClipboardWarrior`.

The SwiftData database continues to use its existing macOS Application Support location. The configurable folder is the local file-autosave destination; this update does not relocate the underlying SwiftData database.

## Export actions

The menu bar `...` menu now offers:

- **Export Individual Clips** — creates one `.md` file for each non-sensitive clip in a folder chosen by the user.
- **Export Archive to Single Markdown** — creates one category-grouped Markdown file.

The redundant Open Archive button in the popover header was removed; Open Archive remains in the `...` menu.

## Local-only build

This build contains no CloudKit implementation and declares no iCloud containers or iCloud services. It does not require an iCloud capability or an iCloud-enabled provisioning profile. Clipboard history remains in the local SwiftData store, and file Autosaver continues to use the configurable local folder (default `~/ClipboardWarrior`).

## Build validation

This environment does not include Xcode or the macOS SDK, so the macOS target could not be compiled or run here. Open `ClipboardWarrior.xcodeproj` in Xcode and build on macOS. Check Signing & Capabilities to confirm that no iCloud capability is present.
