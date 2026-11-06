#!/bin/zsh
set -euo pipefail

APP_NAME="DragConvert"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${CONFIG:-debug}"
ARCH_ARGS=()
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  ARCH_ARGS=(--arch arm64 --arch x86_64)
fi
swift build -c "$CONFIG" "${ARCH_ARGS[@]}"
BIN_PATH="$(swift build -c "$CONFIG" "${ARCH_ARGS[@]}" --show-bin-path)"
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

# Bundled helper tools (WebP encoder and its libraries). Sign each nested
# binary before signing the app so the sandbox can execute it.
if [[ -d "$ROOT/Tools" ]]; then
  mkdir -p "$BUNDLE/Contents/Resources/Tools"
  cp -R "$ROOT/Tools/." "$BUNDLE/Contents/Resources/Tools/"
  chmod +x "$BUNDLE/Contents/Resources/Tools/cwebp"
  for tool in "$BUNDLE/Contents/Resources/Tools/cwebp" "$BUNDLE/Contents/Resources/Tools/"*.dylib; do
    [[ -f "$tool" ]] || continue
    codesign --force --sign - "$tool" >/dev/null 2>&1
  done
fi

codesign --force --sign - \
  --entitlements "$ROOT/Config/DragConvert.entitlements" \
  "$BUNDLE"

# Keep the development bundle out of Spotlight; the installed copy in
# /Applications is the one people should find.
touch "$ROOT/build/.metadata_never_index"

echo "Built and ad-hoc signed: $BUNDLE"
lipo -info "$BUNDLE/Contents/MacOS/$APP_NAME"
