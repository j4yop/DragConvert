# DragConvert — build plan

A macOS utility that converts, edits and moves files **in place**, from a radial wheel that appears during a Finder drag.

Reference: **Tangerine: File Converter** (LEAP STUDIO, macOS 13+, $29.99, v2.0.2). We clone the interaction, not the branding.

---

## 0. The ten decisions

1. **Native Swift 6 + SwiftUI + AppKit.** A webview cannot be an `NSDraggingDestination` mid-drag.
2. **No Accessibility permission.** Poll the drag pasteboard, button state and modifier flags; show a non-activating panel.
3. **Anchor the wheel once.** It must not follow the pointer — that was the first real bug.
4. **Three wheels, one engine.** Convert (⇧), Tools (⌥⌘), Actions (⌃).
5. **Everything local.** No network entitlement.
6. **Write beside the original**, atomically, never overwrite.
7. **Sandbox from day one** + home-folder security-scoped bookmark.
8. **Parity target:** 9 families, ~270 paths, 26 tools, 6 actions. See `PARITY.md`.
9. **Two tracks:** core launch ~week 15, full parity ~week 26 solo.
10. **$29.99 one-time**, 20-file trial.

---

## 1. What the product is

```
drag file → hold ⇧ / ⌥⌘ / ⌃ → wheel appears (anchored)
          → move out to a wedge → release
          → progress toast → new file beside source
```

Three wheels:

| Key | Wheel | Example (PDF) |
|---|---|---|
| ⇧ | Convert | JPG · PNG · TXT · DOCX · EPUB · PPTX · XLSX · MD |
| ⌥⌘ | Tools | Compress · Crop · Annotate · Redact · Add BG · Metadata · Edit |
| ⌃ | Actions | AirDrop · Float · Copy · Move · Copy Path · Terminal |

The wheel shows only operations valid for the dragged file, and never the file’s own format.

---

## 2. Scope

| Phase | Weeks | Families | Paths | Tools |
|---|---|---|---|---|
| **P0** | 1 | spikes | 0 | 0 |
| **P1 core** | 2–6 | Images, PDF | ~85 | crop, compress, resize, rotate, metadata, merge, split, organize, PDF crop, images→PDF, QR |
| **P2 media** | 7–12 | + audio, video, archives | ~170 | + trim/crop/speed/join/split/frames, normalize/trim/channels/bleep, 6 actions |
| **P3 structural** | 13–18 | + docs, slides, sheets, subtitles | ~250 | + annotate, redact, add BG, PPTX renderer, PDF→Office |
| **P4 advanced** | 19–23 | same | ~255 | + photo editor, collage, visualizer, video redact, metadata editor |
| **P5 polish** | 24–26 | same | — | — |

**Non-goals:** DOCX/XLSX→PDF rendering (we do PPTX), pixel-perfect PDF→Office, full PDF text editing, OCR by default, Windows/iOS/cloud, recursive folders, 7z/RAR creation.

---

## 3. The six hard problems

### P1 — Showing UI during a Finder drag

**Decision: be a drop target, not an event interceptor.**

1. 60 Hz timer checks `CGEventSource.buttonState(.left)`.
2. While down, read `NSPasteboard(name: .drag)` for `.fileURL`.
3. Read `NSEvent.modifierFlags` (global static, no permission).
4. Show a borderless `.nonactivatingPanel` at `.popUpMenu` level, anchored once at the pointer.
5. Hover is computed from the **polled pointer**, not from `draggingUpdated`.
6. Release is handled by `performDragOperation` **or** by the polled-pointer fallback on mouse-up, deduplicated.

Verified: the sandboxed app can read the drag pasteboard and writes beside the source.

**Why the fallback exists:** a panel that appears mid-drag does not reliably become the drag destination. The fallback makes the interaction work regardless; the normal path is a bonus.

**Fallback ladder if the pasteboard is ever blocked:** show on any modifier-held drag and filter at drop; then a listen-only `CGEventTap` + Input Monitoring; then `AXUIElement`; then unsandboxed.

### P2 — Writing beside the original

A dropped file grants access to the file, not the parent folder. Ask once for the home folder, store a security-scoped bookmark, `startAccessingSecurityScopedResource()` for the process lifetime. If a write fails, prompt for the folder and retry.

### P3 — Format breadth without a 700 MB dependency

| Family | Primary | Gaps |
|---|---|---|
| Images | ImageIO | libwebp, libavif, resvg |
| PDF | PDFKit, Vision, VisionKit | — |
| Docs | DocModel + ZIPFoundation + `NSAttributedString` | — |
| Slides | OOXML parser + CoreGraphics | — |
| Sheets | OOXML/ODS/BIFF + libxlsxwriter | — |
| Audio | AVFoundation | FFmpeg for MP3/FLAC/OGG/Opus/WMA |
| Video | AVFoundation + VideoToolbox | FFmpeg for MKV/WebM/AVI/WMV |
| Archives | libarchive | — |

macOS has no MP3 encoder, which is why FFmpeg (or LAME) is mandatory for MP3 output.

### P4 — Codec licensing

Ship **LGPL-2.1-only FFmpeg**: `--disable-gpl --disable-nonfree`, no x264/x265, VideoToolbox for encodes, dynamic link, source + relink offer, legal review in week 2. Fallback: drop MP3/OGG/Opus/FLAC/WMA output.

Do not link **Gifski (AGPL)**.

### P5 — Performance and size

Wheel ≤ 80 ms, no main-thread stall > 16 ms, idle CPU ≈ 0, app 60–75 MB.

### P6 — Not becoming a 26-tool monster

Max 10 wedges. v1 ships 9 tools, not 26. Every added tool needs a fixture and a QA pass.

---

## 4. Architecture

```
Finder drag
   │
   ▼
DragSense ── FileDragSession(files, point, modifiers)
   │
   ▼
WheelController ◄── CapabilityGraph (kind → items)
   │  show anchored / hover from pointer
   ▼
JobCore (Job, queue, destination, atomic write)
   │
   ▼
Engines: Image · PDF · Doc · Slide · Sheet · Audio · Video · Subtitle · Archive
   │
   ▼
ProgressCenter → HUD · reveal · haptic · history
```

Shared document spine:

```
PDF/DOCX/PAGES/EPUB/RTF/HTML/PPTX → importer → DocModel (pages → blocks) → exporters
```

### Modules

| Module | Responsibility | Public surface |
|---|---|---|
| **DragSense** | pasteboard, button, modifiers, debounce | `FileDragSession` stream |
| **WheelUI** | panel, geometry, hit-testing, render, haptics | `show/updateHover/hide`, `onDrop` |
| **CapabilityGraph** | kinds, targets, tools, actions | `items(mode:kind:)` |
| **JobCore** | job, queue, naming, atomic writes | `JobQueue`, `DestinationPolicy` |
| **EngineKit** | protocol + errors | `Engine` |
| **DocModel** | pages → blocks | `Document`, `Page`, `Block` |
| **Importers/Exporters** | DOCX, PAGES, EPUB, RTF, HTML, PPTX, XLSX, MD, PDF | `import/export` |
| **RenderService** | DocModel → PDF/PNG, 300 DPI raster | `render` |
| **Platform** | bookmarks, login item, licence, logs | services |
| **Shell** | menu bar, onboarding, settings, history | SwiftUI scenes |

Rule: no engine imports another; no UI imports an engine; a new format is one manifest row + one engine method + one fixture.

### Key types

```swift
struct FileDragSession { let files: [URL]; let point: CGPoint; let modifiers: NSEvent.ModifierFlags }

struct WheelItem { let id: String; let title: String; let symbol: String }

struct Job { let id: UUID; let inputs: [URL]; let operation: JobOperation; let outputDirectory: URL }

protocol Engine: Sendable {
    func run(_ job: Job, progress: @Sendable @escaping (Double) -> Void) async throws -> [URL]
}
```

### Concurrency

Swift 6 strict mode, `@MainActor` UI, actor queue, engines `Sendable`, cancellation within 200 ms (FFmpeg `SIGINT`).

### Error model

`unsupportedFormat`, `permissionDenied`, `diskFull`, `corruptInput`, `cancelled` — each with a human sentence and one recovery action.

### Privacy

No network entitlement. No file names in telemetry. Temp files `0600`, removed on failure. FFmpeg invoked with an argv array, never a shell.

---

## 5. Tech stack

| Layer | Choice |
|---|---|
| Language | Swift 6.4 |
| UI | SwiftUI shell + AppKit overlay + `NSVisualEffectView` |
| Project | Xcode 27 + local SPM packages + XcodeGen |
| Images | ImageIO, CoreGraphics, libwebp, libavif, resvg |
| PDF | PDFKit, CoreGraphics, Vision, VisionKit |
| Docs | DocModel, ZIPFoundation, `NSAttributedString`, Foundation XML |
| Slides | OOXML parser + CoreGraphics |
| Sheets | OOXML/ODS/BIFF + libxlsxwriter |
| A/V | AVFoundation + VideoToolbox + FFmpeg (LGPL) |
| Archives | libarchive |
| Licensing | StoreKit 2 + Keychain trial |
| Updates | App Store / Sparkle 2 |
| CI | GitHub Actions macOS, `swift test` |

Licences: MIT/BSD for libwebp, libavif, resvg, libarchive, libxlsxwriter, ZIPFoundation; LGPL-2.1 for FFmpeg; never AGPL.

---

## 6. Permissions

```
com.apple.security.app-sandbox                     = true
com.apple.security.files.user-selected.read-write = true
com.apple.security.files.bookmarks.app-scope      = true
```

No network, no accessibility, no Apple Events, no full disk.

Onboarding: converter/tools/actions explainer → folder access → launch at login / trial status.

---

## 7. UX spec

| Property | Value |
|---|---|
| Wheel | 340 pt, 4–10 wedges, 2–3° gaps, 14 pt corners |
| Backdrop | warm amber gradient + specular stroke |
| Accent | `#FF6B2C`; hovered wedge fills, label/icon invert |
| Centre | thumbnail, filename, size / “N files” |
| Appear | scale 0.86 → 1, spring 0.28/0.82 |
| Hover | 0.12 s + alignment haptic |
| Keyboard | 1–9, ←/→, ↵, esc, tab |
| Crop | pills Free/1:1/16:9/9:16/4:3/3:4, W/H px, Reset/Apply |
| HUD | 360×86 capsule, “Converting to JPG · 1 of 1 saved”, cancel, auto-dismiss 1.6 s |

Accessibility: VoiceOver labels, full keyboard path, Reduce Motion (fade), Increase Contrast, 200 % text.

---

## 8. Repo

```
App/                  menu bar, welcome, folder access, HUD, headless harness
Packages/
  DragSense/          drag monitor
  CapabilityGraph/     kinds, targets, tools
  WheelUI/             panel, renderer, hover
  JobCore/             job, queue, naming, atomic write
  EngineKit/           protocol
  DocModel/            document spine (P3)
  Importers/ Exporters/ RenderService/ (P3)
  Engines/             Image, PDF, Doc, Slide, Sheet, Audio, Video, Subtitle, Archive
Tests/                unit tests + fixtures
Config/               Info.plist + entitlements
scripts/              bundle + fixtures
```

---

## 9. Costs and requirements

- Apple Developer Program: **$0 to build, $99/yr to distribute**. Ad-hoc signing and sandbox work locally. Pay at launch.
- Domain ~$20/yr, hosting free.
- Optional legal review of LGPL $500–1,500.
- Optional icon/design $0–2,000.
- Fixture corpus, TestFlight testers, privacy policy, support URL.

---

## 10. Risks

| # | Risk | Mitigation |
|---|---|---|
| 1 | Drag path fragile across macOS | Fallback ladder, test matrix |
| 2 | Sandbox write denied | Home-folder bookmark + per-folder retry (verified) |
| 3 | LGPL vs App Store | LGPL-only build + legal review; scope cut ready |
| 4 | Office fidelity expectations | State tiers in the UI |
| 5 | Scope creep | v1 tool list frozen |
| 6 | 120 Hz glass jank | Static gradient fallback |
| 7 | Filenames with emoji/RTL | Middle truncation + corpus |
| 8 | iCloud materialisation stalls | `startDownloadingUbiquitousItem` + timeout |
| 9 | Trial bypass | Keychain + receipt |
| 10 | Project loss | Git + remote backup after every session |

**Red team:** native is required (drag), LibreOffice is not viable (700 MB), cloud/AI breaks the privacy promise, 60 correct paths beat 275 half-tested ones.

---

## 11. Next

See `TASKS.md > NOW` and `WORKFLOW.md §6`. Next week: progress HUD, batch, errors, motion, keyboard, performance.
