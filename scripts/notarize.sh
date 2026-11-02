#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/DragConvert.app"
ZIP="$ROOT/build/DragConvert.zip"

: "${DEVELOPER_ID:?Set DEVELOPER_ID to your Developer ID Application certificate}"
: "${APPLE_ID:?Set APPLE_ID to the Apple ID used for notarization}"
: "${TEAM_ID:?Set TEAM_ID to your Apple Developer team ID}"
: "${NOTARY_PASSWORD:?Set NOTARY_PASSWORD to an app-specific password}"

if [[ ! -d "$APP" ]]; then
  echo "Bundle not found at $APP. Run 'make bundle' first." >&2
  exit 1
fi

echo "Signing with hardened runtime…"
codesign --force --options runtime --timestamp \
  --sign "$DEVELOPER_ID" \
  --entitlements "$ROOT/Config/DragConvert.entitlements" \
  "$APP"

echo "Creating archive…"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "Submitting to Apple…"
xcrun notarytool submit "$ZIP" \
  --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID" \
  --password "$NOTARY_PASSWORD" \
  --wait

echo "Stapling…"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose "$APP"
