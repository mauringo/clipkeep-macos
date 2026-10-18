#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
SWIFT_OPTIONS=(--cache-path "$PWD/.build/cache" --config-path "$PWD/.build/config" --security-path "$PWD/.build/security" -debug-info-format none "$@")
swift build -c release "${SWIFT_OPTIONS[@]}"
BIN_DIR="$(swift build -c release "${SWIFT_OPTIONS[@]}" --show-bin-path)"
APP="${PWD}/dist/Clipboard Assistant.app"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_DIR/ClipboardAssistant" "$APP/Contents/MacOS/.ClipboardAssistant.new"
mv -f "$APP/Contents/MacOS/.ClipboardAssistant.new" "$APP/Contents/MacOS/ClipboardAssistant"
cp Resources/Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp -f LICENSE "$APP/Contents/Resources/LICENSE.txt"
cp -f .build/checkouts/Yams/LICENSE "$APP/Contents/Resources/Yams-LICENSE.txt"
codesign --force --sign - "$APP"
echo "Built: $APP"

# A self-contained Finder installer: bundled app + script, with no Terminal window.
INSTALLER="$PWD/dist/Install Clipboard Assistant.app"
# Build in a temporary directory so a failed build leaves the previous installer intact.
INSTALLER_STAGE="$(mktemp -d "$PWD/dist/.installer.XXXXXX")"
trap 'rm -rf "$INSTALLER_STAGE"' EXIT
osacompile -o "$INSTALLER_STAGE/Install Clipboard Assistant.app" scripts/installer.applescript
INSTALLER_RESOURCES="$INSTALLER_STAGE/Install Clipboard Assistant.app/Contents/Resources"
cp scripts/install-app.sh "$INSTALLER_RESOURCES/install-app.sh"
ditto "$APP" "$INSTALLER_RESOURCES/Clipboard Assistant.app"
codesign --force --sign - "$INSTALLER_STAGE/Install Clipboard Assistant.app"
rm -rf "$INSTALLER"
mv "$INSTALLER_STAGE/Install Clipboard Assistant.app" "$INSTALLER"
echo "Installer: $INSTALLER"
