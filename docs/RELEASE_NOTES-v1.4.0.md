## Menu-bar dropdown and full app mode

- Click the clipboard menu-bar icon for a compact dropdown with search and quick copy. Clicking an entry copies it and closes the dropdown.
- Choose **Expand** for the full history window with previews and export. The Dock icon appears while app windows are open and disappears when the last window closes. Clipboard capture continues.
- The app starts quietly in the menu bar. Right-click the clipboard icon for app commands; Settings and update checking are also available in the dropdown.
- Added a clipboard icon for the Dock and Finder.

## Settings

- **Start at login** registers the app with macOS Login Items. It starts quietly when you sign in. Install the app in Applications before enabling it. Pending macOS approval is shown with a button to open Login Items Settings.
- **Keep history after restart or reboot** is now a switch that applies immediately. Switching it off removes the saved history archive while keeping current entries in memory until quit.
- The entry limit is applied separately with **Apply limit**.

## Install or update

From v1.3.0, choose **Check for Updates… → Install Update** to pull this release tag, build it, and install it. Source updates require Apple Command Line Tools with Swift 6+ and network access.

Alternatively, download the Apple Silicon app or Finder installer archive below. macOS 13+ is required. Binaries are ad hoc signed, without Apple Developer ID signing or notarization, and may be blocked by Gatekeeper. Intel users can build from source.

Validation: 22 Swift tests, isolated updater integration checks, native release build, and app/installer code-signature verification. Live dropdown interaction, Dock transitions, and login approval could not be exercised because UI automation access is unavailable on the release machine; reboot/login was not tested.
