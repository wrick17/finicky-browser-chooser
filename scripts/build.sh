#!/bin/bash
# Builds build/Finicky Browser Chooser.app for Apple silicon, ad-hoc signed. Needs only Xcode command line tools.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Finicky Browser Chooser.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/Info.plist"

clang -fobjc-arc -arch arm64 -mmacosx-version-min=13.0 -Wall -Wextra -Wno-unused-parameter -Werror \
    -framework Cocoa \
    -o "$APP/Contents/MacOS/FinickyBrowserChooser" \
    src/main.m src/Chooser.m

codesign --sign - --force "$APP"
codesign --verify --deep --strict "$APP"
echo "Built $APP"
