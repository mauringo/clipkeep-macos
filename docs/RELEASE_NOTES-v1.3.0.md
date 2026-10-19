Clipboard Assistant’s first packaged GitHub release.

- Native macOS clipboard history for text and images, search, JSON/YAML previews, drag/export, and configurable local retention.
- Automatic daily update checks and a manual **Check for Updates…** menu item.
- **Install Update** pulls the published release tag from GitHub, builds locally, stages and verifies the app, then replaces and relaunches it. Download/build failures preserve the current installation. Requires Apple Command Line Tools with Swift 6+, internet access, and a writable install folder.
- Copyright now identifies **Mauro (mauringo)**. MIT requires retaining the copyright/license notice and permits commercial distribution. Yams notices remain bundled.
- Homebrew cask definition and distribution documentation included in the source; no public tap or official cask submission yet.

## Download and install

**macOS 13+ · Apple Silicon (arm64)**

Download `ClipboardAssistant-1.3.0-arm64.zip`, unzip, and move **Clipboard Assistant.app** into `~/Applications` or another writable Applications folder. The optional installer archive contains a self-contained Finder installer for `~/Applications`.

**Signing:** these are locally ad hoc signed builds, without Apple Developer ID signing or notarization. macOS may block downloaded builds. Building from source is an alternative. Intel users must build from source; the release machine cannot link Intel binaries with its installed toolchain.

```sh
git clone --depth 1 --branch v1.3.0 https://github.com/mauringo/clipkeep-macos.git
cd clipkeep-macos
zsh scripts/build-app.sh
open "dist/Clipboard Assistant.app"
```

Verify downloaded archive checksums against `SHA256SUMS.txt`. Clipboard content is never uploaded; update checking contacts GitHub, and installing a source update also downloads build dependencies.

Validation: 22 Swift tests, isolated updater checks (invalid tag, version mismatch, failed-build preservation, successful source build/replacement), native release build, and code-signature verification. Universal cross-compilation could not link on the release machine; no Intel binary is included.
