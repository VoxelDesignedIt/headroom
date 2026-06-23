#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DIST="$ROOT/dist"
LAUNCHER="$ROOT/Open Headroom.command"

cd "$ROOT"
./build.sh

chmod +x "$LAUNCHER"

cd "$DIST"
rm -f Headroom-macOS.zip
zip -rq Headroom-macOS.zip Headroom.app
cp "$LAUNCHER" "Open Headroom.command"
zip -q Headroom-macOS.zip "Open Headroom.command"
rm "Open Headroom.command"

echo "Release zip: $DIST/Headroom-macOS.zip"
ls -lh "$DIST/Headroom-macOS.zip"
