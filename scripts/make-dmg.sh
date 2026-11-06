#!/bin/zsh
set -euo pipefail

APP_NAME="DragConvert"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Config/Info.plist")"
APP="$ROOT/build/$APP_NAME.app"
DMG="$ROOT/build/$APP_NAME-$VERSION.dmg"

CONFIG=release UNIVERSAL=1 "$ROOT/scripts/make-app-bundle.sh"

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/dragconvert-dmg.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT

cp -R "$APP" "$STAGE/$APP_NAME.app"
ln -s /Applications "$STAGE/Applications"

cat > "$STAGE/Read Me.txt" <<'EOF'
DragConvert

1. Drag DragConvert.app into the Applications folder.
2. Open Applications and launch DragConvert.

This build is universal (Apple Silicon and Intel) and ad-hoc signed.
It is not notarized, so macOS may block the first launch.

If macOS says the app is damaged or cannot be opened:
  - Right-click DragConvert in Applications, choose Open, then Open again, or
  - Run this in Terminal:
      xattr -dr com.apple.quarantine /Applications/DragConvert.app
      open /Applications/DragConvert.app

You can also install with Homebrew:
  brew trust j4yop/tap && brew install --cask j4yop/tap/dragconvert

Source and licence: https://github.com/j4yop/DragConvert
EOF

cat > "$STAGE/Fix Gatekeeper.command" <<'EOF'
#!/bin/zsh
set -e
APP="/Applications/DragConvert.app"
if [[ ! -d "$APP" ]]; then
  echo "DragConvert.app is not in Applications yet."
  echo "Drag it from this window into Applications, then run this again."
  read -k 1 "?Press any key to close."
  exit 1
fi
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
open "$APP"
EOF
chmod +x "$STAGE/Fix Gatekeeper.command"

hdiutil create \
  -volname "DragConvert $VERSION" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$DMG" >/dev/null
hdiutil verify "$DMG" >/dev/null
codesign --force --sign - "$DMG" >/dev/null 2>&1 || true

echo "Built: $DMG"
shasum -a 256 "$DMG"
