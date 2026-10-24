# 🛡️ ClipboardWarrior

**ClipboardWarrior** is a native macOS menu bar clipboard manager built completely in **SwiftUI** and **SwiftData**. 

Unlike standard clipboard managers that keep your history locked inside an app window, ClipboardWarrior bridges your clipboard directly to your Mac's file system. It automatically captures, categorizes, and organizes your clips into real desktop files in real time—giving you instant access and long-term organization without manual effort.

Screenshots:
<img width="892" height="559" alt="Archive" src="https://github.com/user-attachments/assets/79a761d5-5223-40b9-bb17-d66c050899cc" />

<img width="376" height="523" alt="ClipboardWarror General TXT" src="https://github.com/user-attachments/assets/bee5ddd8-4e08-4185-b6a1-0ef41ba16277" />

<img width="373" height="515" alt="ClipboardWarrior Swift" src="https://github.com/user-attachments/assets/a6d8dfc3-e915-4687-8730-fa0ae56116b6" />


---

## ✨ Features

### 📌 Menu Bar Popover & Easy Control
* **Instant Access:** Click the menu bar icon to view recent clips, search, or filter by category.
* **Quick Copy:** Click any clip to copy it straight back to your clipboard.
* **One-Tap Controls:** Pause/resume capture, toggle autosave, open your autosave folder, or export data directly from the menu.

### 🏷️ Smart Language & Syntax Tagging
Every clip receives a color-coded tag powered by a weighted scoring engine to accurately identify languages and file types without misclassifying plain notes:

| Tag | What It Catches |
| :--- | :--- |
| **General Text** | Plain text, notes, and uncategorized snippets |
| **URL** | Web addresses and links |
| **JSON** | Valid JSON objects and arrays |
| **HTML** | Full web pages and HTML snippets |
| **Python** | Python scripts, snippets, and shebang files |
| **Swift** | Swift and SwiftUI code |
| **Bash** | Terminal commands and shell scripts |
| **Image** | Copied images |
| **Files** | Files copied in Finder |

*Each tag displays the originating application (e.g., `HTML · Xcode`).*

### 📂 Desktop Folder Autosave
* **Real-Time File Sync:** Automatically saves clips into an autosave folder on your Desktop (`Desktop/ClipboardWarrior`).
* **Categorized Subfolders:** Creates dedicated subfolders for each category (`Python`, `Swift`, `Bash`, `JSON`, `HTML`, `Images`, `URLs`, `General Text`).
* **Real Extensions:** Save snippets as actual code files (`.py`, `.swift`, `.sh`, `.html`, `.json`) or default to `.txt`.
* **Zero Duplicates:** Re-copying an existing clip updates its timestamp without creating duplicate clutter.
* **Backfill Option:** Easily backfill your entire stored history into your desktop folder at any time.

### 🔐 Built-in Privacy & Sensitive Data Guard
* **Automatic Detection:** Identifies API keys, AWS keys, GitHub tokens, JWTs, passwords, and credit card numbers.
* **Flexible Actions:** Choose to mask sensitive clips, auto-delete them after a set time (e.g., 24 hours), or ignore them entirely.
* **App Exclusion List:** Comes pre-configured to ignore password managers like 1Password, Bitwarden, Keychain Access, and Passwords.
* **100% Local & Offline:** Everything stays on your Mac. ClipboardWarrior makes zero network connections.

### 📁 Archive Window & Customization
* **3-Pane Interface:** Browse by categories, view your clip list, and inspect detailed metadata (source app, copy count, timestamp, file size).
* **Pinning:** Pin essential clips to prevent them from being removed by history limits or age cleanup routines.
* **Hashtag Extraction:** Automatically extracts `#hashtags` from notes for fast searching.
* **Exporting:** Export your entire history to a clean, category-grouped Markdown file (sensitive clips are omitted automatically).

---

## 💻 System Requirements

* **OS:** macOS 14 Sonoma or later
* **Architecture:** Universal (Apple Silicon & Intel Macs)

---

## 🚀 Installation & First Run

1. **Download:** Grab the latest `ClipboardWarrior.zip` from the [Releases page](https://github.com/stevenmotie845/ClipboardWarrior/releases).
2. **Install:** Unzip the archive and move `ClipboardWarrior.app` to your **Applications** folder.
3. **First Launch:**
   * Right-click `ClipboardWarrior.app` and choose **Open** (required for non-notarized releases).
   * Grant **Desktop Folder access** when macOS prompts you so the app can create and manage `Desktop/ClipboardWarrior`.

> 💡 **Tip:** If Desktop access is accidentally denied, go to **System Settings > Privacy & Security > Files & Folders** and enable **Desktop Folder** for ClipboardWarrior.

---

## 🛠️ Upgrading from the Python Version

* **Swift Architecture:** Replaces the legacy `clip_archive.py` script with a full SwiftUI interface and a SwiftData database.
* **Folder Alignment:** Retains the familiar category-per-folder structure on your Desktop.
* **Improved File Safety:** Resolved legacy file-collision issues so rapidly saved clips never overwrite one another.

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.
