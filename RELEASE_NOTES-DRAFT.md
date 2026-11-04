# ClipboardWarrior — Next Release Draft

## New

- **Source app icons:** See the actual macOS app icon beside clips and in the Archive details.
- **Paste selected clip:** Use `Control + Option + Return` to paste the selected clip into the app you're working in.
- **Clear Library:** Delete the complete clipboard history, including pinned clips, with a confirmation step.

## Improved

- Refined the Archive's three-column layout, detail actions, spacing, and window sizing.
- Updated Library category labels to use standard text color while retaining colored category icons and clip-type badges.
- Fixed the Code board icon.
- Polished the menu-bar popover's responsive sizing and source-app presentation.

## Shortcuts

- `Command + Shift + V` — Open clipboard history (default; configurable in Settings).
- `Control + Option + Return` — Paste the selected clip into the frontmost app (can be disabled in Settings).

## Notes

The paste shortcut uses a simulated Command-V keystroke directed to the destination app. macOS Accessibility permission may be required. Files already written to the autosave destination are not removed when clipboard history is cleared.

## Publishing note

The current Xcode project defaults to `~/ClipboardWarrior`. The public README and v2.0.0 release currently describe `Desktop/ClipboardWarrior`; correct that wording when updating the GitHub documentation so the install instructions match the app.
