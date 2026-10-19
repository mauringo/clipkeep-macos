## A faster keyboard workflow, without clutter

- **A tunable global shortcut:** record your own Command, Option, or Control combination in Settings. The default is Control–Option–V. Conflicts keep the previous shortcut. Disable it or reset it at any time.
- **Keyboard navigation:** type to search, use Up/Down to select, and Return to copy and close the menu-bar preview. Text-preview selection keeps its normal arrow-key behavior.
- **Delete from the preview:** a trash icon removes the displayed entry from history without changing the system clipboard. Delete a single row through its right-click menu too.
- **Pinned favorites:** pin text and images from the preview or context menu. Pins appear first and are exempt from the recent-history limit. Their persistence follows the existing history-retention setting; cleaning history still clears pins.
- **Capture exclusions:** choose apps to exclude from future capture. Confidential, transient, and automatically generated clipboard markers are respected by default. This depends on the source app providing markers; unmarked secrets cannot be identified reliably.
- **On-device image text:** recognize text from captured images in the background, search it, preview it, and copy it separately. Images never leave the Mac and original exports stay intact. Recognition can be disabled in Settings.
- **Prebuilt in-app updates:** download a compatible app release instead of building Swift locally. Validate the asset URL, size, SHA-256 digest, archive paths, bundle identity, version, and code integrity before installation. Automatic checking defaults to off for new installations; existing preferences are retained. Homebrew remains the recommended update route.
- **A clearer feature guide:** refreshed feature lists and a short GitHub feature-request form. Tell us which copying, finding, or saving workflow you want to improve.

## Install or update

For Homebrew installations, quit the app and run:

```sh
brew update && brew upgrade --cask mauringo/tap/clipboard-assistant
```

Manual installations can use the Finder installer. Versions through v1.6.2 still build source when using their in-app updater. No Apple signing/notarization claim is made: release apps remain ad hoc signed until a Developer ID certificate is configured.

Validation: 43 Swift tests passed, including old-archive migration, pinned-item retention, privacy rules, on-device OCR, and real signed update archives with invalid identity, corrupted code, and symlink rejection. Legacy updater integration checks passed. Interactive UI verification was skipped at the user's request.

Release app and installer packaging and strict code-signature verification passed. Binary downloads support Apple Silicon on macOS 13+. Intel users can build from the source tag.
