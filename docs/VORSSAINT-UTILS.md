# Vorssaint Utils — repo study

Read-only analysis of <https://github.com/vorssaint/vorssaint-utils> at commit
`a5da763` (29 Oct 2026), version **3.4.3** (build 105).

Purpose: learn architecture and workflow for DragConvert. **No GPL code is copied**
— see §12.

---

## 1. What it is

A single menu-bar app that replaces a dozen paid Mac utilities: per-app volume,
system monitor, app switcher, window layout, Dock previews, clipboard history,
snippets, file shelf, uninstaller, screenshots, recorder, a Dynamic Island, a
command bar, a radial menu, and more.

- **License:** GPL-3.0-or-later
- **Platform:** macOS 14+, Apple Silicon only
- **Distribution:** Homebrew cask + notarized DMG (direct, **not** the Mac App Store)
- **Price:** free, sponsorship-funded
- **Privacy:** no account, no analytics, no telemetry; network only for explicit actions
- **Popularity:** ~32k GitHub stars
- **Version cadence:** 99 changelog releases; 3.4.3 shipped 29 Oct 2026

The product thesis is unusually clear: **one icon, install only what you use**.
Every feature can be switched off in a Features hub; uninstalled features stop
loading and disappear from the UI, and reinstalling restores their settings.

---

## 2. Scale

| Metric | Value |
|---|---|
| Swift files | **706** |
| Swift lines | **313,427** |
| Service directories | **46** |
| UI directories | **24** |
| Test files | **252** |
| Feature switches (`AppFeature`) | **~72** |
| Locales | **15** (en, pt-BR, es, sk, de, fr, it, ja, ko, zh-Hans, zh-TW, zh-HK, tr, ru, uk) |
| External package dependencies | **0** (two system-library shims only) |
| Xcode project | **none** — `build.sh` + `swiftc` |
| AppDelegate | **2,843 lines** |
| Defaults catalogue | **2,806 lines** |
| Source size | 16 MB (Sources), 8.4 MB (Tests) |

This is a 3+ year, multi-thousand-commit product, not a weekend utility. The
scale is the point: the patterns below survived real users, 99 releases and
hundreds of issue-driven fixes.

---

## 3. Repository map

```
Sources/
  Vorssaint/
    App/          AppDelegate, FeatureRuntime, StatusItemController,
                  MenuBarRenderer, popover/panel presentation, main menu
    Core/         FeatureCatalog, Defaults (every key), Localization,
                  per-feature string catalogues, SettingsBackupSupport
    Services/     46 feature services (RadialMenu, Shelf, Audio, Notch,
                  Clipboard, Switcher, Screenshot, Recorder, …)
    UI/           24 matching view folders + OverlayPanel
    Support/      SelfTest, probes, diagnostics
  HIDEventSystem/        system-library shim
  VMStatisticsCompat/    system-library shim
  FanControlHelper/      privileged helper
  NowPlayingAdapter/     dylib loaded by /usr/bin/perl
Tests/            252 Swift test files + shell tests + generate_sources.py
Tools/            make-dmg, notarize, setup-signing, ci-setup-signing, uninstall
Resources/        Info.plist, entitlements, icons, localized strings
docs/             PERMISSIONS, PRIVACY, TROUBLESHOOTING, AI-CONTRIBUTIONS
build.sh          48 KB build/sign/install/test script
.github/          CI, release, issue-fix-status, templates, CODEOWNERS
```

Rule from `CONTRIBUTING.md`: lifecycle in `App`, shared catalogs/preferences in
`Core`, behavior in `Services`, views in `UI`, diagnostics in `Support`.

---

## 4. Architecture

### 4.1 The feature catalog is the source of truth

`Sources/Vorssaint/Core/FeatureCatalog.swift` defines `AppFeature` — one enum
case per switchable feature. The raw value is a **stable persistence identity**
and must never be renamed. Each case declares:

- its hub group (Windows, Mouse, Clipboard, Sound, Tools, Island, Monitor)
- its symbol
- its **enable keys** (any true means engaged)
- the **permissions** it needs
- whether the hardware supports it
- whether it is beta
- how it behaves on first install

Availability is a **layer above** each feature's own enable key:

```swift
var availabilityKey: String { DefaultsKey.featureAvailable(rawValue) }
var isAvailable: Bool { defaults.bool(forKey: availabilityKey) }
```

So there are three independent states per feature:

1. installed (availability) — can the feature exist at all?
2. enabled (its own keys) — is the user using it?
3. permission granted — can it run right now?

This separation is why uninstalling never destroys settings: only the
availability key flips; the enable keys and data stay.

### 4.2 FeatureRuntime — lazy wiring, no eager singletons

`Sources/Vorssaint/App/FeatureRuntime.swift` (447 lines) bridges the pure
catalog to live services through a dictionary of closures:

```swift
private static let bindings: [AppFeature: () -> Void] = [
    .switcher: {
        WindowUseTracker.shared.syncWithFeatures()
        AppSwitcher.shared.syncWithPreferences()
    },
    .dockPreview: { DockPreviewService.shared.syncWithPreferences() },
    …
]
```

Merely naming a feature never instantiates its service. `syncAtLaunch()` skips
unavailable features entirely, so a feature uninstalled in the hub loads
nothing on the next launch. Installing/uninstalling mid-session calls the
binding immediately; the singleton only leaves memory on relaunch, and the hub
shows a restart banner when that matters (`needsRestartToUnload`).

Other runtime responsibilities:

- `loadedThisSession` vs `offerableThisSession` (so a reinstall is not offered
  for removal until the next launch)
- first-run presets (`FeaturePreset.prepareFirstRunAvailability()`)
- install-all, hardware gating, beta opt-ins
- `relaunchApp()` via a detached helper that waits for the process to exit

### 4.3 Services — one feature, one singleton, one sync method

Every service follows the same shape:

```swift
final class SomethingService: ObservableObject {
    static let shared = SomethingService()
    private init() {}
    func syncWithPreferences() { … install/remove monitors, start/stop timers … }
}
```

`syncWithPreferences()` is idempotent: it reads defaults and reconciles the
live state (event taps, global shortcuts, timers, windows). This makes settings
changes, install/uninstall and launch use the same code path.

Services are paired with a UI folder of the same name (`Services/Shelf` ↔
`UI/Shelf`, `Services/RadialMenu` ↔ `UI/RadialMenu`). Reusable decisions live in
a pure `*Support` enum, outside the view, so they can be tested without a window
server.

### 4.4 App shell

`AppDelegate` (2,843 lines) is the lifecycle hub: accessory activation policy,
status item, popover/panel presentation, main menu installation (accessory apps
get none by default), onboarding, settings, update windows, feature runtime
startup, and recovery for system state left behind by a crash.

Notable details worth copying:

- `NSApp.setActivationPolicy(.accessory)` before any window exists
- a hand-installed main menu so ⌘C/⌘V/⌘W work in Settings
- `StatusItemController` with left/right/metric click routing
- panel presentation with activation-source capture, so the app can hand focus
  back to whatever was in front
- explicit recovery for launch-at-login, display brightness, fan control, Spaces

### 4.5 Defaults and settings backup

`Core/Defaults.swift` centralizes **every** `UserDefaults` key in one enum, with
a comment per key and explicit notes for machine state that must never be
exported (e.g. crash-recovery flags). `SettingsBackup` exports/imports the
user-facing keys with those exclusions, via `--export-settings` /
`--import-settings`.

This is a discipline worth adopting before v1: one key registry, machine state
marked, backup designed in.

### 4.6 Localization

15 locales, with per-feature string catalogues (`FeatureStrings`,
`ScreenshotStrings`, `CommandBarStrings`, …) rather than one giant file.
`Localization.swift` is 3,561 lines. Tests validate that every locale has the
same keys and that format arguments keep their identities when reordered
(`TestFormat.parse`).

At DragConvert's stage, English only is fine — but the *shape* (one catalogue
per feature, format-argument validation) is cheap to adopt now.

### 4.7 Support and selftest

`Support/SelfTest.swift` runs with `Vorssaint --selftest`: core capabilities
fail the build, hardware-dependent readings only warn. It checks power
assertions, memory bounds, network counters, icon rendering, defaults
round-trip, SMC, symbolic hotkeys, AirPlay availability.

This is not a unit test; it is a launch-time health check for things that only
exist on a real Mac.

---

## 5. The radial menu — closest thing to our wheel

This is the most directly relevant subsystem. Files:

- `Services/RadialMenu/RadialMenuService.swift` (1,013 lines) — state machine
- `Services/RadialMenu/RadialMenuSupport.swift` (1,206) — models + geometry
- `UI/RadialMenu/RadialMenuView.swift` (507) — SwiftUI wheel

### 5.1 Fixed geometry, pure math

```swift
enum RadialMenuLayout {
    static let panelSize: CGFloat = 400
    static let wheelDiameter: CGFloat = 300
    static let ringRadius: CGFloat = 112
    static let chipSize: CGFloat = 52
    static let hubDiameter: CGFloat = 76
    static let deadZoneRadius: CGFloat = 40
    static let moveActivationDistance: CGFloat = 8
}
```

`RadialMenuGeometry` is a pure enum:

- `angle(dx:dyUp:)` — clockwise from 12 o'clock
- `index(forAngle:itemCount:)`
- `highlightedIndex(dx:dyUp:deadZoneRadius:itemCount:)` — nil in the dead zone
- `unitPosition(index:itemCount:)`

The view and the pointer tracking share the same math, and it is testable
without AppKit.

Two details our wheel should adopt:

1. **Dead zone** around the hub, so the centre never selects.
2. **Move activation distance** — the pointer must travel 8 pt from where the
   wheel opened before a slice starts highlighting, so a centre-screen wheel
   never fires on whatever direction the pointer happened to be in.

### 5.2 Session state machine

The service supports:

- profiles (general, media, browser, custom), each with a colour, shortcut,
  mouse trigger and items
- submenus via a `stack` of item arrays + a `trail`
- hold-to-open vs press-to-open (sticky), with a per-session activation mode
- mouse-button triggers via a `CGEventTap`
- global shortcut triggers
- trackpad tap
- keyboard: digits, arrows, Return, Escape
- Now Playing as a live item
- actions: app, file, URL, shortcut, media key, tool, quick toggle, window layout,
  submenu

The stack is the submenu model: `stack = [items]`, pushing children on submenu,
popping on Escape/back. `trail` drives the breadcrumb.

### 5.3 Keyboard without Accessibility — the key discovery

The panel is a **non-activating panel that can still become key**:

```swift
private final class KeyableWheelPanel: OverlayPanel {
    override var canBecomeKey: Bool { true }
}
```

It is created with `.borderless, .nonactivatingPanel`, level `.statusBar`, and
`WheelMotion.present` calls `panel.makeKey()`. A **local** `keyDown` monitor
then handles arrows/Return/Escape/digits:

```swift
NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
    guard let panel, event.window === panel else { return event }
    return self.handleKeyDown(event) ? nil : event
}
```

No Accessibility, no Input Monitoring, no app activation. This directly solves
DragConvert's parked **WHEEL-2** decision: make the panel keyable, call
`makeKey()` when shown, and add a local key monitor. Our current panel returns
`canBecomeKey = false`, which is why keyboard could not work.

### 5.4 Pointer tracking and dismissal

- local **and** global monitors for `.mouseMoved` / `.leftMouseDragged` etc.
- a `flagsChanged` monitor to detect the summoner key being released
- outside clicks dismiss (local + global)
- `NSWorkspace.didActivateApplicationNotification` dismisses on app switch
- `pointerInside(panel)` uses `panel.frame.insetBy(dx: -2, dy: -2)`
- `PanelDismissal` uses a token so a closing animation that was overtaken by a
  new summon can never order the new panel away

### 5.5 Motion

`WheelMotion.present` fades in over 0.18 s `easeOut`; `dismiss` fades out over
0.13 s `easeIn` and gives key status back on the first frame, so typing
underneath is not eaten. `NSWorkspace.accessibilityDisplayShouldReduceMotion`
is the only switch — no preference.

The SwiftUI view adds scale (0.9 → 1), a spring, an animated highlight wedge
that sweeps the short way around, and a glass disc with rim highlights.

### 5.6 What we should copy

| Pattern | Why |
|---|---|
| Keyable non-activating panel + local key monitor | Unblocks keyboard without a scary permission |
| Pure geometry enum + unit tests | Our `WheelView.index(at:)` should be extracted the same way |
| Dead zone + move activation distance | Prevents accidental selection at the centre |
| `PanelDismissal` token | Avoids stale close animations killing a new wheel |
| 400 pt panel / 300 pt wheel / 112 pt ring | Better proportions than our 340/154 |
| Session stack for submenus | We will need it for “More…” when >10 wedges |
| Reduce Motion as the only motion switch | Simple, correct |

---

## 6. Build and release workflow

### 6.1 `build.sh` — no Xcode project

`Package.swift` exists only for editor indexing; `build.sh` is the real build.

- `--dev` builds a **separate** Developer app (`com.vorssaint.utils.dev`) that
  coexists with the release app and has its own preferences/permissions.
- `--install` installs into `/Applications`.
- `--test`, `--test-suite=NAME`, `--list-tests` run the custom test harness.
- The bundle is staged in a temp directory outside `~/Documents`, because File
  Provider–synced folders add xattrs (`com.apple.provenance`) that invalidate
  codesign.
- Stable local signing matters: macOS ties Accessibility and Screen Recording
  grants to the exact binary hash, so an ad-hoc rebuild orphans them while
  System Settings still shows them granted. The script creates a stable local
  identity if none exists (`Tools/setup-signing.sh`), and warns to
  `tccutil reset` after fixing it.
- Separate code signing for the fan helper and the Now Playing dylib.
- `codesign` retries with timestamp, `notarize.sh`, `make-dmg.sh`.

### 6.2 CI

`.github/workflows/ci.yml`:

- two jobs: `macos-26` build + selftest + DMG + tests; and a **Swift 6.0.3
  compatibility** job on `macos-15` (pinned Xcode 16.2, SDK 15.2)
- actions pinned by commit SHA, `persist-credentials: false`
- `permissions: contents: read`, concurrency with cancellation
- 30-minute timeouts
- no signing on CI (no `--install`)

### 6.3 Release

`.github/workflows/release.yml` is a model of release discipline:

- triggered only by `v[0-9]*` tags
- **preflight** proves the tag names a GitHub-verified commit that is on `main`,
  the tag matches `CFBundleShortVersionString`, and `CHANGELOG.md` has a dated
  entry for that version
- the signing job runs in a protected `release-signing` environment with
  credentials, re-verifies the ref, builds, signs, notarizes the DMG, publishes
  an immutable release
- beta tags stay prereleases and do not replace the stable cask
- rules: never move published tags or replace artifacts

### 6.4 Contribution workflow

`CONTRIBUTING.md` + `docs/AI-CONTRIBUTIONS.md`:

- discuss substantial features in an issue first (need, permissions,
  dependencies, maintenance)
- one PR = one independently useful change
- conventional titles: `type(scope): lowercase imperative phrase`
- `Refs #123` per line, **never** `Closes/Fixes` (the fix-status workflow closes
  after the fix reaches a stable release + two weeks)
- behavior tests must fail without the fix; do not pin private implementation text
- report what was actually verified on which Mac/macOS; compilation is not proof
- leave version bumps and changelog to the maintainer
- agent-assisted work follows the same rules; the human owns the diff and the claims

---

## 7. Testing

- **252 test files**, custom harness, no XCTest.
- `Tests/TestSuite.swift` — `suite.expect`, `expectClose`, per-suite timing,
  non-fatal failures, `TESTS OK (N checks)` / exit code.
- `build.sh --test` compiles a **selected set of production sources** plus
  `Tests/*.swift` into a `VorssaintTests` binary. `Tests/generate_sources.py`
  keeps the list in sync; `PreferenceNamespaceTests` scans every test file for
  preference namespaces.
- Behavior tests **shadow AppKit types** (`NSOpenPanel`, `NSApplication`,
  `NSWindow`, `NSPasteboard`) with local stubs, so panel logic runs without a
  window server. Example: `RadialFilePickerTests`.
- Shell tests for install isolation, uninstall/Spaces, preference cleanup.
- `--selftest` for runtime/hardware.
- CI runs build + selftest + tests + packaging; passing tests alone are
  explicitly *not* accepted as proof the app builds.

For DragConvert, XCTest + SwiftPM is sufficient at our size. The transferable
ideas are: pure support enums, shadowed AppKit for panel logic, and a selftest
for things only a real Mac can check.

---

## 8. Permissions and privacy

The app is **not sandboxed**. It uses the hardened runtime with entitlements for
Apple Events, camera, audio input and calendars, and relies on TCC prompts.

- every permission is optional; denying one turns off only the features that use it
- `AppFeature.permissions` maps each feature to the permissions it needs
- the Permissions page shows which features use each grant, and warns when a
  granted permission is no longer used by anything, with a revoke shortcut
- `docs/PERMISSIONS.md` explains, per permission: why it appears, what uses it,
  what happens if you say no, and that it is optional
- no account, no analytics, no telemetry; network only for visible actions
  (update check, speed test, Homebrew, optional lyrics, expiring links, feedback)

DragConvert is sandboxed and MAS-bound, so the mechanism differs (security-scoped
bookmarks, not TCC), but the **communication pattern** is worth copying: explain
each permission in plain words, tie it to features, and show when it is unused.

---

## 9. Conventions

- SPDX + copyright header on every source file.
- Comments explain **why**, often with an issue number; many encode hard-won
  macOS behaviour (File Provider xattrs, cfprefsd rewriting empty plists,
  accessory apps having no main menu, TCC grants tied to binary hashes).
- Services + matching UI folders; pure `*Support` enums for logic.
- One `DefaultsKey` registry, comments, machine state excluded from backup.
- Stable raw values for anything persisted; migrations for renames.
- No external dependencies; system frameworks and small shims only.
- Localization: per-feature catalogues, 15 locales, format-argument validation.
- Builds must finish without warnings.
- Commits/PRs: `type(scope): lowercase imperative`; one logical change.

---

## 10. What DragConvert should adopt (prioritized)

1. **Keyable wheel panel + local key monitor** — WHEEL-2, today. `canBecomeKey =
   true` on a `.nonactivatingPanel`, `makeKey()` on show, local `keyDown` for
   arrows/Return/Escape/digits. No Input Monitoring.
2. **Pure `WheelGeometry`** — extract our `index(at:)` and angle math into a
   testable enum; add a dead zone (40 pt) and an 8 pt move-activation threshold.
3. **PanelDismissal token + motion** — no stale close, Reduce Motion only.
4. **A `ToolCatalog` with availability and licensing** — our 26 tools should be
   data, with an availability layer above the “enabled” state, so the trial,
   per-tool rollout and “More…” grouping do not become if-statements.
5. **One `DefaultsKey` registry + settings export** — before v1, while there are
   few keys.
6. **Stable local signing identity** — once we ask for any TCC permission
   (folder access is a bookmark, but future Finder/Accessibility features are not).
7. **Release preflight** — tag format, verified commit on main, version match,
   changelog entry, protected signing environment.
8. **Behavior tests with shadowed AppKit** — for wheel hit-testing, drop
   routing, and panel dismissal.
9. **Permission copy** — “why / what uses it / if you say no / optional”.
10. **Why-comments with issue references** — especially around AppKit/macOS quirks.

## 11. What not to adopt

- **The monolith.** 2,843-line `AppDelegate`, 2,806-line `Defaults`, 46 service
  dirs. At 313k lines this is a product, not a template. Our SPM modules are the
  right size for DragConvert.
- **No sandbox.** Their feature set (Accessibility, screen recording, audio taps)
  requires it. We want the Mac App Store; stay sandboxed.
- **72 feature switches / install-uninstall runtime.** We need a trial and 26
  tools, not a feature hub with restart banners.
- **252 test files + custom harness.** XCTest is enough; borrow the *style*, not
  the infrastructure.
- **15 locales at v1.** Externalize strings, ship English.
- **Their motion timings and exact geometry wholesale.** Use them as a
  reference; tune to our 340 pt wheel and our visuals.

## 12. Legal

The repository is **GPL-3.0-or-later**. DragConvert is a proprietary, paid app.
**Do not copy source code, strings, assets, icons, or distinctive visual
designs.** Reading for architectural understanding and reimplementing patterns
independently is fine; copying any code would force GPL obligations on our
binary. The notes above are descriptions, not code to paste.

---

## 13. One-paragraph summary

Vorssaint is a mature, deliberately local-first menu-bar suite built around a
single feature catalog and a lazy runtime: availability is a layer above each
feature’s enable keys, services are idempotent singletons reconciled by
`syncWithPreferences()`, and every feature is paired with a UI folder and a
pure support layer for testability. Its radial menu is the closest reference for
our wheel: fixed geometry with a dead zone, a pure shared math enum, a
non-activating-but-keyable panel for keyboard control without Accessibility,
local+global pointer monitors, a token-based dismissal, and a Reduce-Motion-only
motion model. Its build and release workflow — custom `build.sh`, stable local
signing, selftest, selected-source tests, pinned CI, and a tag-only release
preflight with a protected signing environment — is the discipline we should
copy in smaller form.
