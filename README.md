<div align="center">

<img src="docs/images/clipboard-assistant-icon.png" width="112" height="112" alt="Clipboard Assistant app icon">

# Clipboard Assistant

**A little memory for your Mac’s clipboard.**

Keep the things you copy. Find them again. Save what matters.

[![Build and test](https://github.com/mauringo/clipkeep-macos/actions/workflows/ci.yml/badge.svg)](https://github.com/mauringo/clipkeep-macos/actions/workflows/ci.yml)
[![Cask checks](https://github.com/mauringo/homebrew-tap/actions/workflows/cask.yml/badge.svg)](https://github.com/mauringo/homebrew-tap/actions/workflows/cask.yml)
[![Latest release](https://img.shields.io/github/v/release/mauringo/clipkeep-macos?color=6366f1)](https://github.com/mauringo/clipkeep-macos/releases/latest)
[![MIT license](https://img.shields.io/github/license/mauringo/clipkeep-macos)](LICENSE)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-111827?logo=apple)](docs/DISTRIBUTION.md)
[![Swift](https://img.shields.io/badge/Swift-native-F05138?logo=swift&logoColor=white)](Package.swift)
[![Homebrew tap](https://img.shields.io/badge/Homebrew-personal%20tap-FBB040?logo=homebrew&logoColor=white)](https://github.com/mauringo/homebrew-tap)

[Install](#install-with-homebrew-recommended) · [Update](#update-from-terminal-recommended) · [Releases](https://github.com/mauringo/clipkeep-macos/releases) · [Report an issue](https://github.com/mauringo/clipkeep-macos/issues)

**Native macOS app · Local storage · Text & images · No account required**

</div>

![Clipboard Assistant v1.6 menu-bar dropdown with Start/Stop capture, Copy and Save icons on each row, and a text preview on the right](docs/images/clipboard-assistant-v1.6-menu-bar.png)

Clipboard Assistant remembers your copied texts and images, ready to search, preview, copy again, or save to a file. Keep **100 entries by default**, choose a limit from **1 to 1,000**, and decide whether history survives a restart. It lives in your macOS menu bar and keeps working when you close its window.

## Small app. Useful everyday details.

| Feature | What you get |
| --- | --- |
| 📋 Clipboard history | Text and image entries, newest first, with a configurable limit of 1–1,000 (default: 100). |
| 🔎 Search & filters | Search copied text or switch between text and images. |
| 🖼️ Image previews | Preview copied images before saving them as PNG files. |
| ↩️ Readable text | Wrapped text and clickable links, including long URLs. |
| 🧩 JSON & YAML | Automatically formatted previews with an **Original** switch for the exact source. |
| 💾 Save to a file or folder | Export text as UTF-8 `.txt` and images as `.png`; select several items, add titles, and save them together in a folder. |
| ⏸️ Capture controls | Start or stop capture at the top of the menu-bar preview, or pause and resume from the full window and application menu. |
| ⚙️ History settings | Keep history across restarts or use memory-only capture; clean all entries with one button. |
| 🏠 Stays on your Mac | Local clipboard storage; GitHub is contacted for update checks. |

**Your source stays intact.** JSON and YAML formatting only changes the preview. **Copy** and **Save to…** always use the original clipboard text, including whitespace and comments.

## Get started

### Install with Homebrew (recommended)

With [Homebrew](https://brew.sh) installed:

```sh
brew install --cask mauringo/tap/clipboard-assistant
open "/Applications/Clipboard Assistant.app"
```

This uses our [personal Homebrew tap](https://github.com/mauringo/homebrew-tap) and downloads the prebuilt app. No Swift compiler or local build is needed. The current package supports **Apple Silicon Macs running macOS 13 or later**. Homebrew may ask you to trust this third-party cask.

Already installed manually? Quit the app and move the old **Clipboard Assistant.app** bundle to Trash before switching to Homebrew, including any duplicate in **~/Applications**. Keep **~/Library/Application Support/ClipboardAssistant** to preserve saved history. Session-only history is lost when quitting. Then run the install command above.

After installing, turn off **Clipboard Assistant → Automatically Check for Updates** and use the [Terminal update command](#update-from-terminal-recommended). This keeps Homebrew in charge of app versions.

Current downloads are ad hoc signed and are not Apple notarized. macOS may block first launch; Homebrew does not remove that limitation. See [distribution notes](docs/DISTRIBUTION.md).

### Install without Terminal

Download the app archive from [GitHub Releases](https://github.com/mauringo/clipkeep-macos/releases/latest), unzip it, and move **Clipboard Assistant.app** into Applications. The binary archive supports Apple Silicon Macs. Intel users can build from source. Current builds use an ad hoc signature, without Apple notarization; macOS may block downloaded builds. See [distribution notes](docs/DISTRIBUTION.md).


Double-click **Install Clipboard Assistant.app** in `dist`. It contains the complete app, installs it in **~/Applications**, and opens it. No administrator password or developer tools are required to install or run the built app. Updates quit the running copy before replacing it; history follows your existing retention settings.

You can move the installer on its own, or copy **Clipboard Assistant.app** directly into Applications. Open the `.app` bundle in Finder, rather than the executable inside it, to launch without Terminal.

### Build from source

You’ll need **macOS 13 or later**, **Swift 6 or later**, and the **Apple Command Line Tools**. The first build needs internet access to download the YAML dependency.

From the project folder:

```sh
zsh scripts/build-app.sh
open "dist/Clipboard Assistant.app"
```

The build also creates the self-contained Finder installer. The app starts quietly with a **clipboard icon in your menu bar**. Click it for searchable history with a preview on the right; use the expand icon to open the full app window and show its Dock icon. You can drag `dist/Clipboard Assistant.app` into **Applications** to keep it handy.

Already built the app? Just double-click **Clipboard Assistant.app** inside `dist`.

For scripted installation, run `zsh scripts/install-app.sh`. This installs the existing build and opens it; it does not rebuild or download dependencies.

### Make yourself at home

1. **Copy something.** Text and clipboard images appear automatically while capture is active.
2. **Find it again.** Search your history or filter by **Text** and **Images**.
3. **Select an entry.** Read wrapped text, open a link, inspect formatted JSON/YAML, or preview an image.
4. **Use it.** Choose **Copy** to put it back on the clipboard, or **Save to…** to export a file.

Drag a row’s **three-line handle** or the **Drag** handle above its preview into another app. Images can also be dragged directly from the preview. Text is offered as the original plain text and a `.txt` file; images are offered as PNG data and a `.png` file. The receiving app chooses what it accepts. For part of a text entry, select text in the preview and drag the selection using macOS’s usual text behavior.

![Clipboard Assistant v1.6 full history window with text and image filters, selected items, a text preview, and batch export controls](docs/images/clipboard-assistant-v1.6-history.png)

In the full window, click an entry to show its preview. Use its checkbox, **⌘-click**, or **Shift-click** to select several entries; **Select all** selects the entries matching your current search and filter. A regular click returns to one selected entry. Hidden or deleted entries are removed from the selection.

Choose **Save selected…** to export the selection. Enter a shared title (for example, `Project notes`) to create names such as `Project notes-001.txt` and `Project notes-002.png`. You can also enter an individual title for each item and see its filename before saving. Choose **Choose folder & save…**, then select an existing folder or create one. Files are saved directly into that folder in history order; original text and PNG bytes are preserved. Existing files are kept, and matching names receive a numbered suffix. After saving, choose **Show in Finder** to open the folder.

Right-click any entry for copy, save, and delete actions. Use **Clean history…** to remove all entries.

Click the menu-bar clipboard icon to open history with a preview on the right. Search and click an entry to preview its text or image. Each row has two icons on the left: **Copy** puts the original item on the clipboard and closes the dropdown with a short fade and upward motion, without adding another history entry; **Save** exports the original item to a file. Clicking outside the dropdown, pressing Escape, or clicking the menu-bar icon also uses the same closing animation. Reduce Motion uses a fade only. Use **Start/Stop** at the top to control capture, or the expand icon to open the full app for multi-item selection and export. The Dock icon appears while app windows are open and disappears when the last window closes; capture continues in the menu bar. Right-click the clipboard icon for app commands, or use the dropdown’s **…** menu to check for updates or quit.

## Updates

### Update from Terminal (recommended)

For Homebrew installations, quit Clipboard Assistant, then run:

```sh
brew update && brew upgrade --cask mauringo/tap/clipboard-assistant
open "/Applications/Clipboard Assistant.app"
```

Homebrew refreshes the tap and downloads a prebuilt release when a newer version is available. This avoids the local compilation used by the in-app updater. If you have not installed with Homebrew yet, follow the [installation steps](#install-with-homebrew-recommended) once first.

Turn off **Clipboard Assistant → Automatically Check for Updates** to stop background update prompts. We recommend using Homebrew for both installation and updates, rather than mixing it with the app's updater.

Saved history survives an app replacement. Session-only history is lost when quitting. If you use a custom Homebrew app directory, use that directory when reopening the app.

### Other ways to update

- **Finder installer:** download the latest installer archive from [Releases](https://github.com/mauringo/clipkeep-macos/releases/latest), unzip it, and open **Install Clipboard Assistant.app**. This installs into **~/Applications** and reopens the app. It does not compile source.
- **From a source checkout:** run `git pull --ff-only`, then `zsh scripts/build-app.sh` and `zsh scripts/install-app.sh`. This requires Swift 6+ and Apple Command Line Tools and follows the checked-out branch.

### Optional in-app updater

**… → Check for Updates… → Install Update** remains available for users who prefer it. It downloads the stable release's source and builds on your Mac, so it can take longer and requires **Apple Command Line Tools with Swift 6+**, internet access, and a writable installation destination. Homebrew and the Finder installer use prebuilt apps instead.

Automatic checks run on launch and daily while enabled. They request release metadata from GitHub; clipboard contents are never included. Starting with v1.6.1, protected, renamed, or macOS App Translocation copies install updates into **~/Applications/Clipboard Assistant.app**. Writable copies with the standard name update in place. Build logs are in **~/Library/Application Support/ClipboardAssistant/Updates/update.log**.

### If updating says “Move the app before updating”

Versions through v1.6.0 show this message when the running app cannot be replaced at its current location, including copies that macOS runs from a temporary App Translocation folder. Quit the app, run **Install Clipboard Assistant.app** from the new build or release archive once, and launch **~/Applications/Clipboard Assistant.app**. Saved history is preserved; session-only history is lost when quitting. In v1.6.1 and later, the updater chooses your user Applications folder automatically when the current copy cannot be updated in place.

## History settings

Open **Settings…** from the menu-bar dropdown, the **Clipboard Assistant** application menu, or the **gear** in the full history window. You can also press **⌘,** while an app window is active.

- **Start at login:** use the switch to launch quietly in the menu bar when you sign in to macOS. Install the app in Applications before enabling it. If macOS requires approval, use **Open Login Items Settings…**. The switch reflects macOS registration status; pending approval is shown explicitly.
- **Keep history after restart or reboot:** enabled by default. This switch applies immediately. Turn it off for memory-only history. Switching it off removes the saved archive immediately while keeping current entries available until you quit. The app then starts a new history each time it opens.
- **Maximum entries:** choose any whole number from **1 to 1,000**. The default is **100**. Reducing the limit immediately removes the oldest entries when you click **Apply limit**.
- **Clean history…:** remove all current entries from the app, including saved history, after confirmation. This button is available in both Settings and the main window.

Settings are remembered across restarts even when clipboard history is kept only in memory. Turn on **Start at login** to start capture automatically after signing in.

## Your clipboard, your Mac

When **Keep history after restart or reboot** is enabled, history is stored at:

```text
~/Library/Application Support/ClipboardAssistant/history.json
```

- **Local storage:** clipboard content is never uploaded by the app.
- **Persistent history:** when enabled, text and image data survive restarts, up to your configured limit. With retention off, clipboard entries stay in memory only.
- **Owner-only file permissions:** the archive is restricted to your macOS user, but it is **not encrypted**.
- **Pause when needed:** copied passwords and other sensitive text can be saved like any other text. Pause capture before copying information you don’t want in history.
- **Clear means app history:** clearing history does not erase the system clipboard or files you have already exported.

## A few things to know

- The clipboard is checked every **half second**. Very rapid clipboard changes may be missed.
- The existing clipboard is captured when the app starts. Changes observed while paused are skipped.
- Consecutive identical copies share one history entry. When history exceeds your configured limit, the oldest is removed.
- The app captures plain text and PNG/TIFF clipboard images. Copying a file in Finder does not import its contents.
- JSON and YAML mappings/lists are formatted automatically. Unrecognized or invalid input remains readable as plain text. YAML comments remain available in **Original** mode.
- The build targets your Mac’s processor architecture and uses a local ad hoc signature. Public distribution without Gatekeeper friction requires Developer ID signing and notarization. Use `zsh scripts/build-app.sh --universal` to build both architectures.

## Development

```sh
swift build
swift test
zsh Tests/UpdaterTests/run.sh
```

| Location | Responsibility |
| --- | --- |
| `Sources/ClipboardAssistant` | SwiftUI interface, AppKit text previews, clipboard capture, menu bar, and file export. |
| `Sources/ClipboardCore` | History settings, configurable limits, optional atomic persistence, and JSON/YAML preview formatting. |
| `Tests/ClipboardCoreTests` | History persistence, eviction, duplicate handling, error recovery, and formatting checks. |
| `scripts/build-app.sh` | Release build, app and Finder installer packaging, dependency license, and local signing. |
| `scripts/install-app.sh` | Install the built app in ~/Applications and launch it. |
| `scripts/installer.applescript` | Finder installer interface, with no Terminal window. |

When building inside a restricted development environment that prevents SwiftPM from starting its subprocess sandbox, use:

```sh
zsh scripts/build-app.sh --disable-sandbox
```

## Acknowledgments

YAML previews use **[Yams](https://github.com/jpsim/Yams)**, an MIT-licensed Swift YAML parser built on LibYAML. Its license is included in the built app’s resources.

## License

Copyright © 2026 Mauro (mauringo).

Released under the **[MIT License](LICENSE)**. You may use, modify, and redistribute the app, including commercially, provided you retain the copyright and license notice in all copies or substantial portions of the software. Third-party license notices must also be preserved.

MIT attribution means retaining the copyright and license text in redistributed copies. You may sell the app or future versions; other recipients may also redistribute or sell MIT versions under those terms. Third-party rights remain with their owners.
