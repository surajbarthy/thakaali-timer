#!/usr/bin/env bash
# Builds "Thakaali Timer.app" into ./build.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Thakaali Timer"
EXECUTABLE="ThakaaliTimer"
APP="build/${APP_NAME}.app"

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$EXECUTABLE" "$APP/Contents/MacOS/$EXECUTABLE"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature so macOS will launch it locally.
codesign --force --sign - "$APP"

echo "Built $APP"
echo "Run it with: open \"$APP\""
