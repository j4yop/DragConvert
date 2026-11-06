#!/bin/zsh
set -euo pipefail

APP_NAME="DragConvert"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_PATH="$(swift build --show-bin-path)"
BUILD_BIN="$BIN_PATH/$APP_NAME"
BUNDLE="$ROOT/build/$APP_NAME.app"

if [[ ! -x "$BUILD_BIN" ]]; then
  echo "Binary not found at $BUILD_BIN — run 'swift build' first." >&2
  exit 1
fi

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BUILD_BIN" "$BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ROOT/Config/Info.plist" "$BUNDLE/Contents/Info.plist"

# SwiftPM resources (the wheel's generated tick sound, etc.) live in
# target-specific bundles next to the executable. They must be copied into
# the app bundle or Bundle.module traps at launch.
for resource_bundle in "$BIN_PATH"/*.bundle; do
  [[ -d "$resource_bundle" ]] || continue
  cp -R "$resource_bundle" "$BUNDLE/Contents/Resources/"
done
cp "$ROOT/Config/AppIcon.icns" "$BUNDLE/Contents/Resources/AppIcon.icns"
cp "$ROOT/Config/PrivacyInfo.xcprivacy" "$BUNDLE/Contents/Resources/PrivacyInfo.xcprivacy"
cp "$ROOT/LICENSE" "$BUNDLE/Contents/Resources/LICENSE"

codesign --force --sign - \
  --entitlements "$ROOT/Config/DragConvert.entitlements" \
  "$BUNDLE"

# Keep the development bundle out of Spotlight; the installed copy in
# /Applications is the one people should find.
touch "$ROOT/build/.metadata_never_index"

echo "Built and ad-hoc signed: $BUNDLE"
