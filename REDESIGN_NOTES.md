# ClipboardWarrior redesign notes

## New files
- `MenuBarView.swift`: redesigned menu bar popover (moved out of Views.swift)
- `ArchiveView.swift`: redesigned archive window, sidebar, New Board sheet, clip detail
- `QuickPaste.swift`: Quick Paste shortcut, floating picker that pastes into the app you were using
- `Assets.xcassets/MenuBarIcon*.imageset`: template clipboard glyphs for the menu bar (normal and paused)

## Changed files
- `Views.swift`: type badge, source-app icon (`ClipLeadingIcon`), list and row styling
- `DesignSystem.swift`: tokens, `Confirm` (native alerts), `AppIconProvider`, `CWSymbol`, shared chips
- `GlobalHotKey.swift`: two shortcuts (history + Quick Paste)
- `ClipboardMonitor.swift`: `confirmDeleteAllClips`, `confirmDeletePinnedClips`, `confirmDeleteSensitiveClips`, `postNote`
- `SettingsAndExport.swift`: new Shortcuts section, Accessibility status, native confirmations
- `ClipArchiveApp.swift`: new menu bar icon, "Clips" menu, board icon repair on launch
- `Support.swift`: Quick Paste preferences

## Behavior
- Confirmation prompts now use `NSAlert` instead of `confirmationDialog`, which doesn't survive the menu bar popover losing focus.
- Quick Paste default: ⌃⌘V (alternatives ⌥⇧V, ⌃⇧V). Needs Accessibility permission to press ⌘V; without it the clip is only copied.
- Boards saved with the old `code` icon are repaired to a valid symbol on launch.

Not compiled in the authoring environment. Build and test on macOS before replacing your installed copy.

## Update: popover header removed
- The brand/status header at the top of the menu bar popover is gone. Its actions menu (⋯) now sits beside "Open Archive" in the Recently Copied row; capture status is the Pause Capture switch in the footer.
- Removed the unused `BrandMark` image set.
