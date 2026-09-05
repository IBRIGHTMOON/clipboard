#!/bin/sh
set -eu

TASK_VERSION=${1:?"Usage: scripts/package-app.sh VERSION"}
TASK_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TASK_APP="$TASK_ROOT/dist/ClipboardHistory.app"
TASK_ARCHIVE="$TASK_ROOT/dist/ClipboardHistory-${TASK_VERSION}-arm64.zip"

rm -rf "$TASK_APP" "$TASK_ARCHIVE"
mkdir -p "$TASK_APP/Contents/MacOS"

cp "$TASK_ROOT/packaging/Info.plist" "$TASK_APP/Contents/Info.plist"
CGO_ENABLED=1 go build -o "$TASK_APP/Contents/MacOS/clipboard-history" "$TASK_ROOT"
codesign --force --deep --sign - --identifier com.yang.clipboard-history "$TASK_APP"
ditto -c -k --sequesterRsrc --keepParent "$TASK_APP" "$TASK_ARCHIVE"

shasum -a 256 "$TASK_ARCHIVE"
