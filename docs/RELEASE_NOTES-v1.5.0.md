## Reliable selection and titled batch exports

- Click an item in the expanded history window to show its preview. Row selection now has an explicit click action, separate from the drag handle.
- Select multiple items using checkboxes, ⌘-click, Shift-click, or **Select all**. Selected rows are highlighted, and the selection count stays visible.
- Choose **Save selected…** to save text and images together into a folder.
- Enter a shared title and optional titles for individual items before choosing the destination folder. Filename previews show what will be saved.
- Text exports preserve original UTF-8 contents; images use their original captured PNG data. Files are saved directly in the chosen folder, in history order.
- Existing files are preserved. Matching names receive numbered suffixes; failed exports clean up their own files. Choose **Show in Finder** after saving to open the destination.
- Search/filter changes and history eviction remove hidden or missing entries from the selection. An export keeps a snapshot of the chosen items while clipboard capture continues.

The menu-bar dropdown, expandable app window and Dock behavior, Start at login, immediate retention switch, and source-based updater from earlier releases remain available.

## Install or update

Choose **Check for Updates… → Install Update** in your installed app. The updater pulls this release tag, builds it, and installs it. It requires Apple Command Line Tools with Swift 6+ and network access.

Downloadable app and Finder installer binaries support Apple Silicon on macOS 13+. They are ad hoc signed and are not Apple notarized, so Gatekeeper may block downloaded builds. Intel users can build from source.

Validation: 30 Swift tests, including row selection/range selection, selection pruning, original-data exports, filename safety, duplicate names, existing-file preservation, and invalid exports; updater integration checks; native release build and code-signature checks. Interactive mouse clicks and folder panels could not be exercised because UI automation permission is unavailable on the release machine.
