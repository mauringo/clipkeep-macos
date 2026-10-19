#!/bin/zsh
# Exercise the real updater with local release fixtures; no network or app restart.
set -euo pipefail
PROJECT_ROOT="${0:A:h:h:h}"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/clipboard-updater-test.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
FIXTURE="$TEST_DIR/repository"
DESTINATION="$TEST_DIR/Applications/Clipboard Assistant.app"
mkdir -p "$FIXTURE/Resources" "$FIXTURE/scripts" "$DESTINATION"
print original > "$DESTINATION/original"
cat > "$FIXTURE/Resources/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict><key>CFBundleShortVersionString</key><string>9.0.0</string></dict></plist>
PLIST
cat > "$FIXTURE/scripts/build-app.sh" <<'BUILD'
#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
[[ ! -e fail-build ]] || exit 22
APP="$PWD/dist/Clipboard Assistant.app"
mkdir -p "$APP/Contents/MacOS"
cp Resources/Info.plist "$APP/Contents/Info.plist"
print 'int main(void) { return 0; }' > main.c
xcrun clang main.c -o "$APP/Contents/MacOS/test"
codesign --force --sign - "$APP"
BUILD
cat > "$FIXTURE/scripts/install-app.sh" <<'INSTALL'
#!/bin/zsh
set -euo pipefail
# Test seam: replacement in the temporary install location, without quitting/reopening GUI apps.
DESTINATION="$CLIPBOARD_APPLICATIONS_DIR/Clipboard Assistant.app"
rm -rf "$DESTINATION"
ditto "$1" "$DESTINATION"
INSTALL
git init -q "$FIXTURE"
git -C "$FIXTURE" add .
git -C "$FIXTURE" -c user.name=Test -c user.email=test@example.invalid commit -qm fixture
git -C "$FIXTURE" tag v9.0.0
print fail > "$FIXTURE/fail-build"
git -C "$FIXTURE" add .
git -C "$FIXTURE" -c user.name=Test -c user.email=test@example.invalid commit -qm 'failing build'
git -C "$FIXTURE" tag 9.0.0
# Rewrite only the fixed project URL to the isolated local fixture.
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0="url.file://$FIXTURE.insteadOf"
export GIT_CONFIG_VALUE_0=https://github.com/mauringo/clipkeep-macos.git
if /bin/zsh "$PROJECT_ROOT/scripts/update-from-source.sh" '../invalid' "$DESTINATION" > "$TEST_DIR/invalid.log" 2>&1; then
    print -u2 'Invalid tag was accepted'; exit 1
fi
[[ "$(cat "$DESTINATION/original")" == original ]]
if /bin/zsh "$PROJECT_ROOT/scripts/update-from-source.sh" 9.0.0 "$DESTINATION" > "$TEST_DIR/failure.log" 2>&1; then
    print -u2 'Failed build was accepted'; exit 1
fi
[[ "$(cat "$DESTINATION/original")" == original ]]
/usr/bin/grep -q "Building Clipboard Assistant" "$TEST_DIR/failure.log"
# Wrong version must fail before the fixture build/installer runs.
git -C "$FIXTURE" tag v8.0.0
if /bin/zsh "$PROJECT_ROOT/scripts/update-from-source.sh" v8.0.0 "$DESTINATION" > "$TEST_DIR/mismatch.log" 2>&1; then
    print -u2 'Version mismatch was accepted'; exit 1
fi
[[ "$(cat "$DESTINATION/original")" == original ]]
/usr/bin/grep -q "Release version mismatch" "$TEST_DIR/mismatch.log"
if ! /bin/zsh "$PROJECT_ROOT/scripts/update-from-source.sh" v9.0.0 "$DESTINATION" > "$TEST_DIR/success.log" 2>&1; then
    cat "$TEST_DIR/success.log"; exit 1
fi
[[ ! -e "$DESTINATION/original" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$DESTINATION/Contents/Info.plist")" == 9.0.0 ]]
codesign --verify --deep --strict "$DESTINATION"
print 'Updater checks passed: invalid tag, failed build preserves installation, version mismatch, successful source build and replacement.'
