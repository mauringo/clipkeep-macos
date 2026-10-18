<div align="center">

# 📋 Clipboard Assistant

**A little memory for your Mac’s clipboard.**

Keep the things you copy. Find them again. Save what matters.

**macOS 13+ · Native Swift app · Local storage · Text & images**

</div>

![Clipboard Assistant in dark mode, showing searchable text and image history alongside a clickable link preview](docs/images/clipboard-assistant.png)

Clipboard Assistant remembers your latest **100 copied texts and images**, ready to search, preview, copy again, or save to a file. It lives in your macOS menu bar and keeps working when you close its window.

## Small app. Useful everyday details.

| Feature | What you get |
| --- | --- |
| 📋 Clipboard history | The latest 100 text and image entries, newest first, preserved across app restarts. |
| 🔎 Search & filters | Search copied text or switch between text and images. |
| 🖼️ Image previews | Preview copied images before saving them as PNG files. |
| ↩️ Readable text | Wrapped text and clickable links, including long URLs. |
| 🧩 JSON & YAML | Automatically formatted previews with an **Original** switch for the exact source. |
| 💾 Save to a file | Export text as UTF-8 `.txt` and images as `.png`, using the native macOS save dialog. |
| ⏸️ Capture controls | Pause and resume from the window or the clipboard icon in the menu bar. |
| 🏠 Stays on your Mac | No account, cloud sync, or network service. |

**Your source stays intact.** JSON and YAML formatting only changes the preview. **Copy** and **Save to…** always use the original clipboard text, including whitespace and comments.

## Get started

### Build from source

You’ll need **macOS 13 or later**, **Swift 6 or later**, and the **Apple Command Line Tools**. The first build needs internet access to download the YAML dependency.

From the project folder:

```sh
zsh scripts/build-app.sh
open "dist/Clipboard Assistant.app"
```

The app opens its history window and adds a **clipboard icon to your menu bar**. You can drag `dist/Clipboard Assistant.app` into **Applications** to keep it handy.

Already built the app? Just double-click **Clipboard Assistant.app** inside `dist`.

### Make yourself at home

1. **Copy something.** Text and clipboard images appear automatically while capture is active.
2. **Find it again.** Search your history or filter by **Text** and **Images**.
3. **Select an entry.** Read wrapped text, open a link, inspect formatted JSON/YAML, or preview an image.
4. **Use it.** Choose **Copy** to put it back on the clipboard, or **Save to…** to export a file.

Right-click any entry for copy, save, and delete actions. Use **Clear history…** to remove all saved entries.

Closing the window leaves capture running. Click the menu bar clipboard icon to reopen history, pause capture, or **Quit Clipboard Assistant**.

## Your clipboard, your Mac

History is stored at:

```text
~/Library/Application Support/ClipboardAssistant/history.json
```

- **Local storage:** clipboard content is never uploaded by the app.
- **Persistent history:** text and image data survive restarts, up to the latest 100 entries.
- **Owner-only file permissions:** the archive is restricted to your macOS user, but it is **not encrypted**.
- **Pause when needed:** copied passwords and other sensitive text can be saved like any other text. Pause capture before copying information you don’t want in history.
- **Clear means app history:** clearing history does not erase the system clipboard or files you have already exported.

## A few things to know

- The clipboard is checked every **half second**. Very rapid clipboard changes may be missed.
- The existing clipboard is captured when the app starts. Changes observed while paused are skipped.
- Consecutive identical copies share one history entry. When history exceeds 100 entries, the oldest is removed.
- The app captures plain text and PNG/TIFF clipboard images. Copying a file in Finder does not import its contents.
- JSON and YAML mappings/lists are formatted automatically. Unrecognized or invalid input remains readable as plain text. YAML comments remain available in **Original** mode.
- The build targets your Mac’s processor architecture and uses a local ad hoc signature. Distribution to other Macs requires Developer ID signing and notarization.

## Development

```sh
swift build
swift test
```

| Location | Responsibility |
| --- | --- |
| `Sources/ClipboardAssistant` | SwiftUI interface, AppKit text previews, clipboard capture, menu bar, and file export. |
| `Sources/ClipboardCore` | History limit, atomic persistence, and JSON/YAML preview formatting. |
| `Tests/ClipboardCoreTests` | History persistence, eviction, duplicate handling, error recovery, and formatting checks. |
| `scripts/build-app.sh` | Release build, `.app` packaging, dependency license, and local signing. |

When building inside a restricted development environment that prevents SwiftPM from starting its subprocess sandbox, use:

```sh
zsh scripts/build-app.sh --disable-sandbox
```

## Acknowledgments

YAML previews use **[Yams](https://github.com/jpsim/Yams)**, an MIT-licensed Swift YAML parser built on LibYAML. Its license is included in the built app’s resources.

## License

Copyright © 2026 Clipboard Assistant contributors.

Released under the **[MIT License](LICENSE)**. You may use, modify, and redistribute the app, including commercially, provided you retain the copyright and license notice in all copies or substantial portions of the software. Third-party license notices must also be preserved.
