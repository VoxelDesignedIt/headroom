#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$DIR/Headroom.app"

if [ ! -d "$APP" ]; then
    osascript -e 'display alert "Headroom.app not found" message "Unzip Headroom-macOS.zip first, then double-click Open Headroom.command in the same folder as Headroom.app."'
    exit 1
fi

xattr -cr "$APP" 2>/dev/null || true
open "$APP"
