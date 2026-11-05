# 🛡️ ClipboardWarrior

**ClipboardWarrior** is a native macOS menu bar clipboard manager built completely in **SwiftUI** and **SwiftData**.

Unlike standard clipboard managers that keep your history locked inside an app window, ClipboardWarrior bridges your clipboard directly to your Mac's file system. It automatically captures, categorizes, and organizes your clips into real local files in real time—giving you instant access and long-term organization without manual effort.

**Screenshots:**

<img width="1076" height="751" alt="clipboardwarrior_archive" src="https://github.com/user-attachments/assets/03699875-cd78-4678-a7e8-b2d43eaca732" />

<img width="376" height="523" alt="ClipboardWarrior General TXT" src="https://github.com/user-attachments/assets/bee5ddd8-4e08-4185-b6a1-0ef41ba16277" />

<img width="373" height="515" alt="ClipboardWarrior Swift" src="https://github.com/user-attachments/assets/a6d8dfc3-e915-4687-8730-fa0ae56116b6" />

---

## ✨ Features

### 📌 Menu Bar Popover & Easy Control

- **Instant Access:** Click the menu bar icon to view recent clips, search, or filter by category.
- **Global Keyboard Shortcut:** Press **⌘ Command + ⇧ Shift + V** from anywhere on your Mac to instantly open your clipboard history.
- **Quick Copy:** Click any clip to copy it straight back to your clipboard.
- **One-Tap Controls:** Pause/resume capture, toggle autosave, open your autosave folder, or export data directly from the menu.

### 🏷️ Smart Language & Syntax Tagging

Every clip receives a color-coded tag powered by a weighted scoring engine to accurately identify languages and file types without misclassifying plain notes:

| Tag | What It Catches |
| :--- | :--- |
| **General Text** | Plain text, notes, and uncategorized snippets |
| **URL** | Web addresses and links |
| **HTML** | Full web pages and HTML snippets |
| **Python** | Python scripts, snippets, and shebang files |
| **Swift** | Swift and SwiftUI code |
| **Bash** | Terminal commands and shell scripts |
| **Image** | Copied images |
| **Files** | Files copied in Finder |

*Each tag displays the originating application (e.g., `HTML · Xcode`).*

### 📂 Local Folder Autosave

- **Real-Time File Sync:** Automatically saves clips into an autosave folder on your Desktop (`Desktop/ClipboardWarrior`).
- **Categorized Subfolders:** Creates dedicated subfolders for each category (`Python`, `Swift`, `Bash`, `HTML`, `Images`, `URLs`, `General Text`).
- **Real Extensions:** Save snippets as actual code files (`.py`, `.swift`, `.sh`, `.html`) or default to `.txt`.
- **Real-Time File Sync:** Automatically saves clips into `~/ClipboardWarrior` by default. Choose any folder during first-run setup or change the destination later in Settings.
- **Categorized Subfolders:** Creates dedicated subfolders for each category (`Python`, `Swift`, `Bash`, `JSON`, `HTML`, `Images`, `URLs`, `General Text`).
- **Real Extensions:** Save snippets as actual code files (`.py`, `.swift`, `.sh`, `.html`, `.json`) or default to `.txt`.
- **Zero Duplicates:** Re-copying an existing clip updates its timestamp without creating duplicate clutter.
- **Backfill Option:** Easily backfill your entire stored history into the selected folder at any time.
- **Backup & Restore:** Create a portable JSON backup of your clips, boards, metadata, and image payloads, then merge it into another ClipboardWarrior library.

### 🔐 Built-in Privacy & Sensitive Data Guard

- **Automatic Detection:** Identifies API keys, AWS keys, GitHub tokens, JWTs, passwords, and credit card numbers.
- **Flexible Actions:** Choose to mask sensitive clips, auto-delete them after a set time (e.g., 24 hours), or ignore them entirely.
- **App Exclusion List:** Comes pre-configured to ignore password managers like 1Password, Bitwarden, Keychain Access, and Passwords.
- **Local Storage:** Clipboard history stays in the local SwiftData database, and autosaved files stay in the local folder you choose. No cloud account or cloud capability is required.

### 📁 Archive Window & Customization

- **3-Pane Interface:** Browse by categories, view your clip list, and inspect detailed metadata (source app, copy count, timestamp, file size).
- **Pinning:** Pin essential clips to prevent them from being removed by history limits or age cleanup routines.
- **Hashtag Extraction:** Automatically extracts `#hashtags` from notes for fast searching.
- **Exporting:** Export every clip as an individual Markdown file, or export the full archive to one category-grouped Markdown document. Sensitive clips are omitted automatically.
- **First-Run Setup:** Choose your local autosave folder, configure capture preferences, and review Quick Paste permissions.
- **Shortcut diagnostics:** Settings reports when a global shortcut could not be registered or conflicts with the other ClipboardWarrior shortcut.
- **Application Exclusions:** Add installed apps or bundle identifiers that ClipboardWarrior must never read from.

---

## 💻 System Requirements

- **OS:** macOS 14 Sonoma or later
- **Architecture:** Apple Silicon and Intel where the release build is configured for both architectures.

---

## 🚀 Installation & First Run

1. **Download:** Grab the latest signed release from the [Releases page](https://github.com/stevenmotie845/ClipboardWarrior/releases).
2. **Install:** Open the downloaded disk image or archive and move `ClipboardWarrior.app` to your **Applications** folder.
3. **First Launch:**
   - Follow Gatekeeper prompts. A public website release should be Developer ID signed and notarized before publication.
   - Complete the first-launch setup. Keep the default `~/ClipboardWarrior` folder or choose your own location.
   - You can change the autosave destination at any time under **Settings > Autosave to folder**.
   - ClipboardWarrior runs locally and does not request an iCloud capability or provisioning profile.
   - Quick Paste's automatic keystroke requires Accessibility access; clipboard capture itself does not require that permission.

---

<<<<<<< HEAD
=======
## 🛠️ Upgrading from the Python Version

- **Swift Architecture:** Replaces the legacy `clip_archive.py` script with a full SwiftUI interface and a SwiftData database.
- **Folder Alignment:** Retains the familiar category-per-folder structure under the chosen local autosave folder (default `~/ClipboardWarrior`).
- **Improved File Safety:** Resolved legacy file-collision issues so rapidly saved clips never overwrite one another.

---

>>>>>>> 0675a95 (updated clipboard warrior project all)
## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.
