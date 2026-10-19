#!/bin/zsh
# Invoked by the app with a validated stable GitHub release tag.
set -euo pipefail
TAG="${1:?Release tag required}"
DESTINATION_APP="${2:?Installed app path required}"
# Never build a branch, arbitrary URL, or user-supplied shell command.
if [[ ! "$TAG" =~ '^v?[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
    print -u2 'Invalid release tag.'
    exit 1
fi
if [[ "$DESTINATION_APP" != /*.app || ! -w "${DESTINATION_APP:h}" ]]; then
    print -u2 'Move the app to a writable Applications folder before updating.'
    exit 1
fi
xcrun --find swift >/dev/null
xcrun --find git >/dev/null
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/clipboard-update.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT
print "Downloading release $TAG…"
/usr/bin/git -c core.hooksPath=/dev/null clone --depth 1 --branch "$TAG" --single-branch \
    https://github.com/mauringo/clipkeep-macos.git "$WORK_DIR/source"
SOURCE_DIR="$WORK_DIR/source"
EXPECTED_VERSION="${TAG#v}"
ACTUAL_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$SOURCE_DIR/Resources/Info.plist")"
[[ "$ACTUAL_VERSION" == "$EXPECTED_VERSION" ]] || { print -u2 'Release version mismatch.'; exit 1; }
print 'Building Clipboard Assistant…'
/bin/zsh "$SOURCE_DIR/scripts/build-app.sh"
NEW_APP="$SOURCE_DIR/dist/Clipboard Assistant.app"
/usr/bin/codesign --verify --deep --strict "$NEW_APP"
# The installer stages and verifies the app before asking the running app to quit.
# Run outside the source tree so cleanup cannot remove the current working directory.
cd "$WORK_DIR"
CLIPBOARD_APPLICATIONS_DIR="${DESTINATION_APP:h}" /bin/zsh "$SOURCE_DIR/scripts/install-app.sh" "$NEW_APP"
