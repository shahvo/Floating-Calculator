#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Floating Calculator"
VERSION="1.0"
APP_PATH=".build/$APP_NAME.app"
DIST_DIR="dist"
ZIP_PATH="$DIST_DIR/FloatingCalculator-$VERSION-macOS.zip"

./build-app.sh

mkdir -p "$DIST_DIR"

if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_PATH"
    codesign --verify --deep --strict "$APP_PATH"
fi

rm -f "$ZIP_PATH"
ditto -c -k --keepParent --norsrc --noextattr "$APP_PATH" "$ZIP_PATH"

echo "Packaged $ZIP_PATH"
