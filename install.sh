#!/bin/bash
# Builds ExtraDock with Swift Package Manager, wraps it in an app bundle,
# installs it, and launches it. No Xcode project needed.
#
#   ./install.sh               build, install to /Applications, and launch
#   ./install.sh --build-only  only build build/ExtraDock.app
set -euo pipefail

APP_NAME="ExtraDock"
INSTALL_DIR="/Applications"
ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_ONLY=false
if [ "${1:-}" = "--build-only" ]; then
    BUILD_ONLY=true
fi

cd "$ROOT"

echo "Building $APP_NAME..."
swift build -c release --product "$APP_NAME"
BIN_DIR="$(swift build -c release --show-bin-path)"

APP_PATH="$ROOT/build/$APP_NAME.app"
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP_PATH/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$APP_PATH/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP_PATH/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP_PATH/Contents/PkgInfo"

# Ad-hoc signature: lets macOS attach permissions (Accessibility, login item) to the app.
codesign --force --sign - "$APP_PATH"

echo "Build successful: $APP_PATH"
if [ "$BUILD_ONLY" = true ]; then
    exit 0
fi
echo ""

# Replace a running copy (settings and Custom Dock items are saved as you change them).
if pgrep -xq "$APP_NAME"; then
    echo "Quitting running $APP_NAME..."
    pkill -x "$APP_NAME" || true
    sleep 1
fi

if [ ! -w "$INSTALL_DIR" ]; then
    INSTALL_DIR="$HOME/Applications"
    mkdir -p "$INSTALL_DIR"
fi

# Install to /Applications
if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
    echo "Removing existing $APP_NAME from $INSTALL_DIR..."
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
fi

echo "Installing to $INSTALL_DIR..."
cp -R "$APP_PATH" "$INSTALL_DIR/"

echo "Done! $APP_NAME installed to $INSTALL_DIR/$APP_NAME.app"
open "$INSTALL_DIR/$APP_NAME.app"
echo "Launched. Look for the dock icon in your menu bar."
