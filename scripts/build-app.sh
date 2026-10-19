#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
UNIVERSAL=false
if [[ "${1:-}" == "--universal" ]]; then
    UNIVERSAL=true
    shift
fi
SWIFT_OPTIONS=(--cache-path "$PWD/.build/cache" --config-path "$PWD/.build/config" --security-path "$PWD/.build/security" -debug-info-format none "$@")
APP="${PWD}/dist/Clipboard Assistant.app"
mkdir -p "$APP/Contents/MacOS"
if $UNIVERSAL; then
    mkdir -p .build/universal
    for ARCH in arm64 x86_64; do
        swift build -c release --arch "$ARCH" "${SWIFT_OPTIONS[@]}"
        ARCH_BIN="$(swift build -c release --arch "$ARCH" "${SWIFT_OPTIONS[@]}" --show-bin-path)"
        cp "$ARCH_BIN/ClipboardAssistant" ".build/universal/ClipboardAssistant-$ARCH"
    done
    lipo -create .build/universal/ClipboardAssistant-arm64 .build/universal/ClipboardAssistant-x86_64 -output "$APP/Contents/MacOS/.ClipboardAssistant.new"
else
    swift build -c release "${SWIFT_OPTIONS[@]}"
    BIN_DIR="$(swift build -c release "${SWIFT_OPTIONS[@]}" --show-bin-path)"
    cp "$BIN_DIR/ClipboardAssistant" "$APP/Contents/MacOS/.ClipboardAssistant.new"
fi
mv -f "$APP/Contents/MacOS/.ClipboardAssistant.new" "$APP/Contents/MacOS/ClipboardAssistant"
cp Resources/Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp -f LICENSE "$APP/Contents/Resources/LICENSE.txt"
cp -f .build/checkouts/Yams/LICENSE "$APP/Contents/Resources/Yams-LICENSE.txt"
cp -f scripts/update-from-source.sh "$APP/Contents/Resources/update-from-source.sh"
cp -f scripts/install-app.sh "$APP/Contents/Resources/install-app.sh"
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
