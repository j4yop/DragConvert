# Packaging and distribution

DragConvert builds locally as an ad-hoc-signed, sandboxed app:

```bash
make run        # build + bundle + launch
make bundle     # build + bundle only
```

The bundle lives at `build/DragConvert.app`. To install the current build for
normal use and Spotlight search:

```bash
make install
```

This copies the signed bundle to `/Applications/DragConvert.app`, registers it
with LaunchServices, imports it into Spotlight, and removes the development
bundle so search shows one copy with the wheel icon.

## Universal DMG

```bash
make dmg
```

`make dmg` builds the release binary for both **arm64 and x86_64**, creates
`build/DragConvert-<version>.dmg`, adds an `/Applications` shortcut, a Read Me
and a quarantine-fix command, then signs the DMG ad-hoc. Verify it with:

```bash
hdiutil attach -nobrowse -readonly build/DragConvert-<version>.dmg
lipo -info "/Volumes/DragConvert <version>/DragConvert.app/Contents/MacOS/DragConvert"
codesign --verify --deep --strict "/Volumes/DragConvert <version>/DragConvert.app"
hdiutil detach "/Volumes/DragConvert <version>"
```

The app is universal but still ad-hoc signed. Without a Developer ID
certificate, Gatekeeper will not accept it on first launch. The DMG includes
the exact `xattr` fix, and the Homebrew cask clears quarantine automatically.
When a Developer ID and notary credentials are available, run `make notarize`
and replace the ad-hoc DMG.

## Homebrew release

The public tap is `j4yop/homebrew-tap` and the cask is `Casks/dragconvert.rb`.
For each release:

1. Bump `CFBundleShortVersionString` and `CFBundleVersion` in `Config/Info.plist`.
2. `make bundle`
3. `ditto -c -k --keepParent build/DragConvert.app build/DragConvert-<version>.zip`
4. `shasum -a 256 build/DragConvert-<version>.zip`
5. Create the GitHub release and upload the zip as `DragConvert-<version>.zip`.
6. Update `j4yop/homebrew-tap/Casks/dragconvert.rb` with the version and SHA-256.

Install:

```bash
brew trust j4yop/tap && brew install --cask j4yop/tap/dragconvert
```

## What is already wired

- **App icon:** `Config/AppIcon.icns`, generated from `Config/AppIcon-1024.png` by `scripts/make-icon.swift`. The bundle script copies it into `Contents/Resources`.
- **Menu-bar template icon:** drawn in code by `App/StatusIcon.swift`; macOS tints it for light/dark menu bars and the busy state uses the accent colour.
- **About / privacy / licences:** `About DragConvert` in the menu bar shows the version, the GPL-3.0 licence, the privacy statement, update status, and links to the GitHub repository, releases and licence.
- **Update path:** the About tab checks `api.github.com` for the latest GitHub release on launch and once a day. The toggle can disable it, and **Check Again** is always manual. No account, identifier or telemetry is sent. The app therefore declares the `com.apple.security.network.client` entitlement; keep the privacy copy in step with that.
- **Version:** `Config/Info.plist` (`CFBundleShortVersionString`, `CFBundleVersion`). Bump both for every user-visible release.
- **Sandbox:** `Config/DragConvert.entitlements` has app sandbox, user-selected read/write, app-scoped bookmarks and the network client entitlement used only for the GitHub release check.

## Notarization (Developer ID)

Notarization needs an Apple Developer Program membership, a Developer ID Application certificate, and an app-specific password. It cannot be completed with the current ad-hoc identity.

The script is `scripts/notarize.sh`. Use:

```bash
DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" \
APPLE_ID="you@example.com" \
TEAM_ID="TEAMID" \
NOTARY_PASSWORD="app-specific-password" \
./scripts/notarize.sh
```

It re-signs the bundle with the hardened runtime, submits it with `notarytool --wait`, and staples the ticket. Check the result with:

```bash
spctl --assess --type execute --verbose build/DragConvert.app
```

## App Store

The project already uses App Sandbox and user-selected file access, which is the right base. For the App Store:

1. `xcodegen generate` to produce the Xcode project.
2. Set the team and bundle identifier `com.dragconvert.app`.
3. Add a 1024×1024 App Store icon (the same artwork is fine).
4. Add the privacy policy URL and support URL.
5. Declare **Data Not Collected** in App Privacy. The app has no analytics, account or telemetry; the only request is an unauthenticated GitHub release check.
6. The app already includes `Config/PrivacyInfo.xcprivacy` (no tracking, no collected data, no accessed-API declarations). Keep it in the target resources.
7. Archive, upload, and use TestFlight before release.

**Do not add StoreKit or a paywall.** DragConvert is GPL-3.0-only and free. The source is the corresponding source for every binary release.

## Release checklist

- [ ] `swift test`
- [ ] `make bundle`
- [ ] Version and build number bumped
- [ ] App icon and menu-bar icon visible in light and dark mode
- [ ] About window opens and the licence/privacy links work
- [ ] `spctl` / notarization passes (Developer ID build)
- [ ] README, PARITY and TASKS updated
- [ ] Tag and push; the menu's `Check for Updates…` points at the releases page
