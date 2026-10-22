#!/bin/bash
# Installs or updates Finicky Browser Chooser in ~/Applications from a prebuilt release.
# Builds nothing, needs no sudo, and never touches Finicky itself or its settings.
#
#   curl -fsSL https://raw.githubusercontent.com/wrick17/finicky-browser-chooser/main/scripts/install.sh | bash
#
# Optional environment:
#   CHOOSER_VERSION           Release tag to install (default: latest release)
#   CHOOSER_RELEASE_BASE_URL  Directory holding the release assets (overrides CHOOSER_VERSION)
#   CHOOSER_SHA256            Expected archive checksum, checked in addition to SHA256SUMS
#   CHOOSER_INSTALL_DIR       Install directory (default: ~/Applications)

set -euo pipefail

REPO="wrick17/finicky-browser-chooser"
BUNDLE_ID="io.github.wrick17.finicky-browser-chooser"
APP_NAME="Finicky Browser Chooser.app"
ASSET="FinickyBrowserChooser-arm64.tar.gz"
INSTALL_DIR="${CHOOSER_INSTALL_DIR:-$HOME/Applications}"
INSTALL_DIR="${INSTALL_DIR%/}"
TARGET="$INSTALL_DIR/$APP_NAME"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

fail() { echo "chooser-install: $*" >&2; exit 1; }
info() { echo "chooser-install: $*"; }
is_chooser() { [ "$(defaults read "$1/Contents/Info" CFBundleIdentifier 2>/dev/null)" = "$BUNDLE_ID" ]; }

[ "$(uname -s)" = "Darwin" ] || fail "This app only runs on macOS."
[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 13 ] || fail "This app needs macOS 13 or later."
# Check the hardware, not the shell: a Rosetta shell reports x86_64 on Apple silicon.
[ "$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" = "1" ] ||
    fail "Releases are built for Apple silicon only. Build from source on Intel Macs."

if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
    if [ -L "$TARGET" ] || [ ! -d "$TARGET" ] || ! is_chooser "$TARGET"; then
        fail "$TARGET is a different app, so it will not be replaced. Nothing was installed."
    fi
fi
WRITE_CHECK="$INSTALL_DIR"
[ -d "$WRITE_CHECK" ] || WRITE_CHECK="$(dirname "$INSTALL_DIR")"
[ -w "$WRITE_CHECK" ] || fail "Cannot write to $WRITE_CHECK. Set CHOOSER_INSTALL_DIR to a folder you own. Nothing was installed."

if [ -n "${CHOOSER_RELEASE_BASE_URL:-}" ]; then
    BASE_URL="${CHOOSER_RELEASE_BASE_URL%/}"
elif [ -n "${CHOOSER_VERSION:-}" ]; then
    BASE_URL="https://github.com/$REPO/releases/download/$CHOOSER_VERSION"
else
    BASE_URL="https://github.com/$REPO/releases/latest/download"
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/chooser-install.XXXXXX")"
STAGED=""
trap 'rm -rf "$WORK"; [ -z "$STAGED" ] || rm -rf "$STAGED"' EXIT

fetch() {
    curl --fail --silent --show-error --location --proto '=https,file' --tlsv1.2 \
        --retry 2 --output "$2" "$1"
}

info "Downloading release from $BASE_URL"
fetch "$BASE_URL/SHA256SUMS" "$WORK/SHA256SUMS" || fail "No release found at $BASE_URL. Nothing was installed."
EXPECTED="$(awk -v asset="$ASSET" '$2 == asset || $2 == "*" asset { print $1 }' "$WORK/SHA256SUMS")"
[ -n "$EXPECTED" ] || fail "This release has no $ASSET. Nothing was installed."
if [ -n "${CHOOSER_SHA256:-}" ] && [ "$CHOOSER_SHA256" != "$EXPECTED" ]; then
    fail "SHA256SUMS does not match CHOOSER_SHA256. Nothing was installed."
fi
fetch "$BASE_URL/$ASSET" "$WORK/$ASSET" || fail "Could not download $ASSET. Nothing was installed."
[ "$(shasum -a 256 "$WORK/$ASSET" | awk '{ print $1 }')" = "$EXPECTED" ] ||
    fail "Checksum mismatch for $ASSET. Nothing was installed."
info "Checksum verified"

# bsdtar refuses absolute paths and '..' entries unless -P is given.
mkdir "$WORK/extract"
tar -xzf "$WORK/$ASSET" -C "$WORK/extract"
NEW_APP="$WORK/extract/$APP_NAME"
[ "$(ls -A "$WORK/extract")" = "$APP_NAME" ] || fail "Archive must contain only $APP_NAME. Nothing was installed."
[ -d "$NEW_APP" ] && [ ! -L "$NEW_APP" ] || fail "$APP_NAME in the archive is not a directory. Nothing was installed."
is_chooser "$NEW_APP" || fail "Archive app is not $BUNDLE_ID. Nothing was installed."
EXECUTABLE="$NEW_APP/Contents/MacOS/FinickyBrowserChooser"
[ -f "$EXECUTABLE" ] && [ ! -L "$EXECUTABLE" ] || fail "Archive app has no executable. Nothing was installed."
lipo -archs "$EXECUTABLE" 2>/dev/null | tr ' ' '\n' | grep -qx arm64 || fail "Archive app is not built for arm64. Nothing was installed."
codesign --verify --deep --strict "$NEW_APP" 2>/dev/null || fail "Archive app signature is invalid. Nothing was installed."
info "App checked: $BUNDLE_ID, arm64, signature valid"

# Stage next to the target so the swap is a rename.
mkdir -p "$INSTALL_DIR"
STAGED="$INSTALL_DIR/.$APP_NAME.installing-$$"
ditto "$NEW_APP" "$STAGED"

# The chooser quits on its own when idle; only ask it to quit, never force it.
running() { pgrep -qxf "$TARGET/Contents/MacOS/FinickyBrowserChooser( .*)?"; }
if running; then
    info "Asking the running chooser to quit"
    osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        running || break
        sleep 0.5
    done
    if running; then
        fail "The chooser is still running. Close its panel, then rerun. Nothing was installed."
    fi
fi

BACKUP=""
if [ -e "$TARGET" ]; then
    # Not ending in .app, so macOS does not register the backup as a second copy.
    BACKUP="$TARGET.backup-$(date +%Y%m%d-%H%M%S)"
    mv "$TARGET" "$BACKUP" || fail "Could not move the old app aside. Nothing was installed."
fi
if ! mv "$STAGED" "$TARGET"; then
    [ -z "$BACKUP" ] || mv "$BACKUP" "$TARGET"
    fail "Could not install to $TARGET. The previous version was restored."
fi
STAGED=""

# Register the bundle ID so Finicky's 'open -b' can find the app. This does not change your default browser.
# Custom install folders (such as test fixtures) are left unregistered.
if [ -z "${CHOOSER_INSTALL_DIR:-}" ]; then
    "$LSREGISTER" -f "$TARGET" >/dev/null 2>&1 || info "Note: could not register the app with Launch Services."
fi

info "Installed $TARGET"
if [ -n "$BACKUP" ]; then
    info "Previous version saved at $BACKUP"
    info "Roll back with: rm -rf \"$TARGET\" && mv \"$BACKUP\" \"$TARGET\""
fi
info "Finicky and ~/.finicky.js were not changed. See the README for the handler to add."
