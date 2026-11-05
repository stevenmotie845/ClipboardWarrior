# ClipboardWarrior 2.1.0 — Release Readiness Notes

## Included in this update

- Local JSON backup and merge-based restore for clipboard clips, boards, metadata, and available image payloads.
- Explicit warning that backups are unencrypted and contain sensitive clipboard content when present.
- Swift 6 concurrency-oriented fix for the global shortcut preference observer using a selector-based NotificationCenter observer.
- Shortcut registration diagnostics in Settings, including duplicate History / Quick Paste key combinations and Carbon registration failures.
- macOS deployment target reset to 14.0 (the minimum platform level for the SwiftData and Observation APIs used in this project).
- Version updated to 2.1.0 (build 2).
- Removed hard-coded Development Team ID to allow signing with the team selected in Xcode.
- Removed a stale Desktop-only folder usage description.

## Preserved

- Local-only operation; no CloudKit or iCloud capability.
- Default Autosaver folder `~/ClipboardWarrior` and the ability to choose another folder during onboarding or in Settings.
- Clipboard history, Boards, Pinned clips, Quick Paste, global shortcuts, app exclusions, Autosaver, onboarding, and Markdown exports.

## Validation performed

- All Swift files passed Swift 6 parser validation (`swiftc -swift-version 6 -parse`).
- Xcode project, plist, entitlements, and asset catalog JSON were checked for valid structure.
- ZIP integrity test passed.
- Source and entitlements were checked for CloudKit and iCloud capability references.

## Validation not performed

- No full macOS compile or runtime test: this environment does not include Xcode or the macOS SDK. Parser validation is not a substitute for a macOS build.
- No signing, notarization, or stapling.
- No App Store validation. App Sandbox remains disabled for the direct-distribution development configuration.

## Before publication

1. Open the project in Xcode on macOS and build with the intended release team.
2. Test backup and restore with text, code, URLs, boards, pinned clips, sensitive clips, and images. Keep a copy of the original library before testing restore.
3. Test first launch, folder selection, bookmark persistence, and Autosaver after restarting the Mac.
4. Run the full functional checklist on both Apple Silicon and Intel, if both are supported by the final architecture settings.
5. Create a separate App Store sandboxed build configuration and verify all capabilities and user-selected-folder behavior before submitting.
6. Sign the website build with Developer ID, notarize it, staple the ticket, and test Gatekeeper on a clean Mac user account.
7. Complete privacy policy, support page, store metadata, screenshots, review notes, and release documentation.
