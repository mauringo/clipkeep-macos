#!/bin/zsh
# Install the built app for the current user. No administrator password is needed.
set -euo pipefail
SOURCE_APP="${1:-${0:A:h:h}/dist/Clipboard Assistant.app}"
APPLICATIONS_DIR="${CLIPBOARD_APPLICATIONS_DIR:-$HOME/Applications}"
DESTINATION_APP="$APPLICATIONS_DIR/Clipboard Assistant.app"

if [[ ! -d "$SOURCE_APP/Contents/MacOS" ]]; then
    print -u2 "Build the app first with: zsh scripts/build-app.sh"
    exit 1
fi
/usr/bin/codesign --verify --deep --strict "$SOURCE_APP"
mkdir -p "$APPLICATIONS_DIR"
# Stage and verify before replacing an existing installation.
STAGING_DIR="$(mktemp -d "$APPLICATIONS_DIR/.clipboard-install.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
/usr/bin/ditto "$SOURCE_APP" "$STAGING_DIR/Clipboard Assistant.app"
/usr/bin/codesign --verify --deep --strict "$STAGING_DIR/Clipboard Assistant.app"
# Ask a running copy to quit normally before installing the update.
/usr/bin/osascript -e 'if application id "com.clipboardassistant.mac" is running then tell application id "com.clipboardassistant.mac" to quit'
if [[ -e "$DESTINATION_APP" ]]; then
    mv "$DESTINATION_APP" "$STAGING_DIR/Previous.app"
fi
if ! mv "$STAGING_DIR/Clipboard Assistant.app" "$DESTINATION_APP"; then
    [[ ! -e "$STAGING_DIR/Previous.app" ]] || mv "$STAGING_DIR/Previous.app" "$DESTINATION_APP"
    exit 1
fi
/usr/bin/open "$DESTINATION_APP"
print "Installed: $DESTINATION_APP"
