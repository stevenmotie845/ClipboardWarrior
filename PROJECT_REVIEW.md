# ClipboardWarrior project update

## Included changes

- Reworked the menu-bar popover with a branded ClipboardWarrior mark, shared design tokens, search, Recent/Pinned/Boards navigation, category filtering, clip cards, and a compact footer.
- Replaced protection-oriented status copy with clipboard-manager wording.
- Added a Pause Capture switch.
- Moved autosave enablement and folder actions into the overflow menu under Autosave to Folder; the footer displays the destination folder name rather than a generic Autosave button.
- Changed the default autosave destination to `~/ClipboardWarrior`. Existing users with the exact former `~/Desktop/ClipboardWarrior` default are migrated; custom folder choices are preserved.
- Added destructive, confirmation-protected actions to clear pinned clips or the entire clipboard history, including pinned clips. Associated image payloads are removed through the existing clip deletion path. Already-autosaved files are intentionally left untouched.
- Preserved the uploaded project's SwiftData model, capture engine, detector, global shortcut, archive, settings, and persistence implementation.

## Validation

Swift syntax parsing was run for all project Swift source files. A full Xcode/macOS build and interactive runtime test could not be run in this environment; please build and test on macOS before replacing the working installation.
