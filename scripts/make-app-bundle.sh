#!/bin/zsh
set -euo pipefail

APP_NAME="DragConvert"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_BIN="$ROOT/.build/debug/$APP_NAME"
BUNDLE="$ROOT/build/$APP_NAME.app"

if [[ ! -x "$BUILD_BIN" ]]; then
  echo "Binary not found at $BUILD_BIN — run 'swift build' first." >&2
  exit 1
fi

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BUILD_BIN" "$BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ROOT/Config/Info.plist" "$BUNDLE/Contents/Info.plist"
cp "$ROOT/Config/AppIcon.icns" "$BUNDLE/Contents/Resources/AppIcon.icns"
cp "$ROOT/Config/PrivacyInfo.xcprivacy" "$BUNDLE/Contents/Resources/PrivacyInfo.xcprivacy"

codesign --force --sign - \
  --entitlements "$ROOT/Config/DragConvert.entitlements" \
  "$BUNDLE"

# Keep the development bundle out of Spotlight; the installed copy in
# /Applications is the one people should find.
touch "$ROOT/build/.metadata_never_index"

echo "Built and ad-hoc signed: $BUNDLE"
