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

Source-built updates are locally compiled and ad hoc signed; they are not notarized vendor binaries. Users need Apple Command Line Tools, Swift 6+, network access, and a writable install directory. Builds execute source and build tooling from the trusted project release and its dependency.

## Homebrew

This native GUI app fits a **cask**, rather than a source formula. `Casks/clipboard-assistant.rb` describes the published Apple Silicon archive using its exact SHA-256 checksum, app name, and macOS minimum.

For a personal tap, create a public repository named `homebrew-tap` under `mauringo`, copy the cask into its `Casks` directory, and publish it. Users can then run:

```sh
brew tap mauringo/tap
brew install --cask mauringo/tap/clipboard-assistant
```

The tap repository is separate from this application repository and is not created by the build. Do not advertise that install command as available until the tap is published. Homebrew can subsequently update the installed binary with `brew upgrade --cask clipboard-assistant`. For Homebrew-managed installs, turn off the app’s automatic checks if you want Homebrew to manage all updates.

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
