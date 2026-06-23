#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Headroom"
BUILD_DIR="$ROOT/.build/release"
APP_BUNDLE="$ROOT/dist/$APP_NAME.app"

echo "Building $APP_NAME..."
cd "$ROOT"
swift build -c release

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ROOT/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
if [ -f "$ROOT/../brand/output/AppIcon.icns" ]; then
  cp "$ROOT/../brand/output/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "Code signing..."
codesign --force --deep --sign - --entitlements "$ROOT/Headroom.entitlements" "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

echo "Built: $APP_BUNDLE"
