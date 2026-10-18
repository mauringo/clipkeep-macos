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
