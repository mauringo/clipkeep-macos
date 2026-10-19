## Consistent native preview dismissal

- Clicking outside the menu-bar preview now runs the same short fade, scale, and upward motion as Copy.
- Escape and clicking the menu-bar icon share the same closing animation.
- Reduce Motion continues to use a fade only.
- Closing repeatedly cannot schedule multiple dismissals. Forced closes and reopening clear pending close tasks and restore the preview for the next opening.

The native macOS popover, search, preview, and Copy/Save controls remain simple and familiar.

Install through **… → Check for Updates… → Install Update**, or use the Finder installer. If a version through v1.6.0 shows “Move the app before updating,” use the installer once and launch the copy in **~/Applications**.

Validation: all 32 Swift tests, debug and release builds, app and installer packaging, and strict code-signature checks passed. Interactive verification of the animation remains unavailable because Computer Use permissions are not granted.
