#!/bin/sh
# Packages the release build as a drag-to-Applications DMG.
#   flutter build macos --release && tool/package_macos.sh 0.1.0
# Output: dist/FlSony-<version>-macos.dmg
set -eu
cd "$(dirname "$0")/.."

VERSION="${1:?usage: tool/package_macos.sh <version>}"
APP=build/macos/Build/Products/Release/FlSony.app
OUT="dist/FlSony-$VERSION-macos.dmg"

[ -d "$APP" ] || { echo "Missing $APP; run 'flutter build macos --release' first." >&2; exit 1; }

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/FlSony.app"
ln -s /Applications "$STAGE/Applications"

mkdir -p dist
rm -f "$OUT"
hdiutil create -quiet -volname "FlSony $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO "$OUT"
echo "$OUT"
