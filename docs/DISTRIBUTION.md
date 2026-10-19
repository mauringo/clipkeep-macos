# Release and Homebrew distribution

## Publish a release

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist`.
2. Run `swift test`, then `zsh scripts/build-app.sh --universal`.
3. Zip the app and optional Finder installer with `ditto -c -k --sequesterRsrc --keepParent`.
4. Publish a stable GitHub release tagged `v<CFBundleShortVersionString>` with the archives and SHA-256 checksums. The source at that tag must have the same version. The app updater builds this exact tag; do not move published tags.
5. Update the cask URL, version, and checksum for each release.

Clipboard data is not included in release archives. Bundled license notices include Mauro (mauringo)’s MIT license and Yams’ upstream license.

The first v1.3.0 binary release is Apple Silicon only: the local Swift 6.4 toolchain lacks Intel compatibility libraries. `--universal` requires a toolchain that supports both architectures (the macOS 15 CI runner is configured to check this). Intel users can build the tagged source on their own machine.

## Signing

Current release builds are ad hoc signed, not Developer ID signed or notarized. Downloaded builds may be blocked by Gatekeeper. There is no signing identity installed on the release machine. A smooth binary release needs Apple Developer Program membership, a Developer ID Application certificate, hardened runtime signing, notarization using `xcrun notarytool`, and stapling using `xcrun stapler`. Both the app and any distributed installer need an appropriate signing/notarization process. Never remove quarantine attributes automatically.

Source-built updates are locally compiled and ad hoc signed; they are not notarized vendor binaries. Users need Apple Command Line Tools, Swift 6+, network access, and a writable install directory. Starting with v1.6.1, protected, renamed, or App Translocation copies install updates into `~/Applications/Clipboard Assistant.app`; writable copies with the standard name update in place. Builds execute source and build tooling from the trusted project release and its dependency.

## Homebrew

This native GUI app fits a **cask**, rather than a source formula. `Casks/clipboard-assistant.rb` describes the published Apple Silicon archive using its exact SHA-256 checksum, app name, and macOS minimum.

### Install and update from the personal tap

The public tap is [mauringo/homebrew-tap](https://github.com/mauringo/homebrew-tap). With Homebrew installed, users can install the prebuilt Apple Silicon app with:

```sh
brew install --cask mauringo/tap/clipboard-assistant
open "/Applications/Clipboard Assistant.app"
```

This command adds the tap automatically. Homebrew may ask users to trust the third-party cask. The tap is independent of the official Homebrew catalog; current downloads remain ad hoc signed and are not notarized, so macOS may block first launch.

For updates, quit the app and run:

```sh
brew update && brew upgrade --cask mauringo/tap/clipboard-assistant
open "/Applications/Clipboard Assistant.app"
```

**Recommend Homebrew-managed updates.** Turn off **Clipboard Assistant → Automatically Check for Updates**. Homebrew downloads a prebuilt app and avoids the local source build performed by the optional in-app updater. A Swift compiler is not required for Homebrew installation or updates.

When switching from manual installation, quit the app and move the previous app bundle to Trash, including any duplicate in `~/Applications`, before installing the cask. Preserve `~/Library/Application Support/ClipboardAssistant` to keep saved history. Session-only history is lost when quitting. If a custom Homebrew app directory is configured, reopen the app from that directory.

### Maintain the tap

The tap is a separate repository. For every release, update the version and SHA-256 checksum in this repository's `Casks/clipboard-assistant.rb`, copy that cask to the tap, and push both repositories. A new GitHub release alone does not update Homebrew's version metadata. Run:

```sh
brew style --cask mauringo/tap/clipboard-assistant
brew info --cask --json=v2 mauringo/tap/clipboard-assistant
brew fetch --cask mauringo/tap/clipboard-assistant
```

The tap's CI checks the checked-out cask's style, metadata, and release download checksum. These checks do not claim Apple notarization or official catalog acceptance.

### Official Homebrew catalog

Official `homebrew/cask` inclusion requires a stable, verifiable upstream download, correct version and checksum, an app that passes current Gatekeeper checks without bypasses, and compliance with the shared acceptance policy, including adoption/maintenance requirements. A new repository and an ad hoc signed archive are not ready for official submission. Sign and notarize first, establish usage, run `brew audit --cask --online` and `brew style`, then submit a pull request following the current policies.

References:
- https://docs.brew.sh/Adding-Software-to-Homebrew
- https://docs.brew.sh/Cask-Cookbook
- https://docs.brew.sh/Acceptable-Casks
- https://docs.brew.sh/Package-Acceptance-Policy

## Similar software

- Maccy: lightweight native Mac clipboard history, search, and keyboard access. https://maccy.app/
- Paste: commercial clipboard manager with Apple-device sync and reusable snippets. https://pasteapp.io/
- CopyQ: cross-platform history with editing, tabs, scripting, and custom commands. https://hluk.github.io/CopyQ/

Clipboard Assistant currently emphasizes local text/image history, original-source export and drag operations, and readable JSON/YAML previews. These features are its current focus, not a claim of uniqueness.
