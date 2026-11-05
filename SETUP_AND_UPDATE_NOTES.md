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


## Release-readiness update (2.1.0, build 2)

- Added `BackupRestore.swift` with a versioned JSON backup that includes clips, boards, metadata, and image payloads. Restore merges only new clip hashes and does not overwrite existing clips.
- Backups include clips marked sensitive. The UI warns before export/import because backup files are not encrypted and may contain private clipboard data.
- Added Backup & Restore actions to Settings.
- Reworked `GlobalHotKey.swift` to use a selector-based preference observer instead of capturing an actor-isolated `self` in an asynchronous observer closure. Shortcut registration errors and duplicate History/Quick Paste assignments are surfaced in Settings.
- Updated marketing version to 2.1.0 and build number to 2.
- Set the macOS deployment target to 14.0, matching the SwiftData/Observation APIs used by this app and avoiding an unnecessarily high machine-specific deployment target.
- Removed the stale Desktop-only folder usage description; the user can choose any local destination.
- Removed the hard-coded development team so the project can be signed by the team selected in Xcode.
- Preserved local-only operation, the `~/ClipboardWarrior` default, custom folder selection, Autosaver, exclusions, onboarding, and Markdown export.

## Distribution status and remaining release gates

This project remains configured for direct macOS development/distribution with App Sandbox disabled and Hardened Runtime enabled. It is **not yet an App Store submission build**: App Store distribution requires an App Sandbox configuration and a tested user-selected-folder permission flow. Do not switch App Sandbox on in this project without validating bookmarks, default-folder onboarding, clipboard monitoring, and Quick Paste on macOS.

A full macOS build, runtime test, Developer ID signing, notarization, and stapling could not be performed in this Linux environment because Xcode and the macOS SDK are unavailable. Those steps remain required before publishing a website download. App Store screenshots, privacy policy URL, support URL, privacy declarations, and review notes must also be finalized before submission.
