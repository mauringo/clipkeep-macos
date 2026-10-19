## Update from protected or relocated app copies

- Fix the “Move the app before updating” failure for protected, renamed, and macOS App Translocation copies.
- Keep writable installations named **Clipboard Assistant.app** in their existing location.
- Otherwise, install the new release into **~/Applications/Clipboard Assistant.app**, creating the folder when needed. The progress window explains when the update will move the app.
- Report a missing update helper separately from installation-location problems.
- Refresh documentation with v1.6 screenshots of the menu-bar preview and expanded history window.

The fix takes effect after installing v1.6.1. If v1.6.0 or earlier is already showing the error, quit the app and use the Finder installer once, then launch the copy in **~/Applications**. Saved clipboard history remains available; session-only history is lost when quitting.

Validation: 32 Swift tests passed, including writable-installation, protected-path, renamed-app, and App Translocation destination checks. Updater integration checks, release packaging, and strict code-signature verification also passed. Interactive UI verification remains unavailable because Computer Use permissions are not granted.
