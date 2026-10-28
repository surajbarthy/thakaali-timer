#!/usr/bin/env bash
# Builds "Thakaali Timer.app" into ./build.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Thakaali Timer"
EXECUTABLE="ThakaaliTimer"
APP="build/${APP_NAME}.app"

# One binary for both Apple Silicon and Intel Macs.
ARCHS=(--arch arm64 --arch x86_64)
swift build -c release "${ARCHS[@]}"
BIN_DIR="$(swift build -c release "${ARCHS[@]}" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$EXECUTABLE" "$APP/Contents/MacOS/$EXECUTABLE"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp -R Resources/Fonts "$APP/Contents/Resources/Fonts"

# Ad-hoc signature so macOS will launch it locally.
codesign --force --sign - "$APP"

echo "Built $APP"
echo "Run it with: open \"$APP\""
