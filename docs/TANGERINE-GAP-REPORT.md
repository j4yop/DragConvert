# Tangerine 2.0.2 vs DragConvert — comprehensive gap report

**Date:** 3 November 2026  
**Scope:** Tangerine's current website, tools pages, press kit, demo video, App Store listing (v2.0.2), release notes, independent reviews, and the public launch discussion; audited against the DragConvert source tree.  
**Method:** Direct page/JS/JSON scraping, press-kit and tool-window screenshots, App Store/iTunes metadata, Agent Reach web/Reddit research, and a five-advisor council with anonymous peer review. No Tangerine code or assets were copied.

> **Implementation update — 6 November 2026 (0.7.0):** the format and control surface now mirrors the reference: the three wheels use the recorded option sets and spacing, Settings has the full grouped Formats catalog with per-format quality/metadata/PDF-layout/compression/bitrate/bit-depth controls, and Compatibility has all seven format groups. Opt+Cmd and Ctrl+Cmd are the Tools/Actions defaults. New real engines: WebP encoding (bundled cwebp), PDF/A-2B output, QR detection on PDFs, SRT/VTT/TXT subtitles, and ZIP/TAR/GZIP archives. The remaining document/spreadsheet/audio/video engines are registered in the UI and marked as the next family. No Tangerine code or assets are included.
>
> **Implementation update — 6 November 2026 (0.6.0):** the 1:1 interaction pass is built. The wheel now has both reference materials — dark translucent **Glass** with an orange hover and opaque **Solid** with a light hover — plus the file header above the wheel, the hovered-format centre capsule, the 0.2 s bloom, SF Rounded labels, 120 Hz crossfade, hover tick and haptics. Settings is now the reference’s dark five-tab window: **General | Formats | Compatibility | Folders | About**, with the orange Glass/Solid segmented control, checkboxes, orange modifier/float/terminal popups, folder access and a GPL-3.0 About tab. The progress HUD is a compact dark glass card with success/deny motion. Quality and Preserve metadata feed the image encoder; **Command** is the default Tools modifier. The previous warm sidebar/About windows are gone. This supersedes the 0.5.0 note below. No Tangerine code or assets are included.
>
> **Implementation update — 6 November 2026 (0.5.0):** the interaction/design pass is built: a 0.2 s bloom from scale 0.45, the reference `#FF5200` hover colour, a real blurred glass ring, SF Rounded labels with tracking, a 120 Hz hover crossfade, an original 60 ms tick plus haptics, warm HUD success/deny animations, a warm sidebar Settings window, a matching About window, comma-to-settings while the wheel is open, and a menu-bar/Dock switch. The earlier 0.3.0 P0 release is also built. The wheel now filters every wedge through a working engine, stays open after the modifier is released, defaults to ⇧⌥, puts Copy on the clipboard, handles mixed image/PDF selections and correct GIF/PPTX/RTFD kinds, draws a thumbnail + size in the centre, and ships with an app icon, menu-bar template, About/privacy/licences and an update link. AVIF export and PDF→TXT/Markdown with local OCR are in; PDF balanced compression and PDF→image annotation regression tests pass. Remaining: WebP/SVG, PDF/A-2b and PDF→Office, metadata editing, deeper photo/annotate/redact controls, video/audio/documents, hide-menu-bar and real Dock-drag QA. See `TASKS.md` for the live status.

---

## Bottom line

DragConvert has a genuinely good core: a native, sandboxed, keyboard-navigable drag wheel that writes beside the original and runs locally. It is also now free and GPL-3.0-licensed, which is a real advantage over Tangerine's $29.99 one-time price.

But it is **not yet a credible Tangerine alternative on breadth**, and more importantly, **the wheel currently promises conversions it cannot perform**. That is the first thing to fix.

The honest state:

| Area | Tangerine 2.0.2 | DragConvert today | Status |
|---|---|---|---|
| Families | 9 (images, video, audio, PDF, documents, slides, spreadsheets, EPUB, subtitles, archives) | 2 (images, PDF) | 🔴 Far behind |
| Conversion paths | 275 | ~30–40 image/PDF paths | 🔴 ~12–15% |
| Advertised paths | All supported | ~270 shown in graph; many fail | 🔴 P0 trust issue |
| Tools | 26, all shipped | 17 implementations, images/PDF only | 🟠 Behind in depth |
| Actions | 6, fully shipped | 6, Copy/Terminal semantics wrong | 🟠 Mostly there |
| Core wheel behavior | Sticky, selection-aware, thumbnail/size | Hides on key release, flat, filename only | 🔴 Core UX gap |
| Packaging | App Store, icon, notarized, updates | ad-hoc, no icon/notarization/updates | 🔴 Not shippable |
| Price | $29.99, 20-file trial | Free, GPL-3.0, no limits | 🟢 Ahead |
| OS / chip | macOS 13+, Apple silicon only | macOS 13+; source can support Intel | 🟢 Potential edge |
| Privacy | Local, policy promise | Local, no network entitlement | 🟢 Auditable edge |

**Recommended sequence:** a one-week **“Truthful Wheel”** release (hide what does not work, fix the core interaction), then **WebP/AVIF/SVG + PDF OCR/PDF-A**, then an **optional FFmpeg provider** for audio/video. Do **not** try to match all 275 paths, and do **not** bundle LibreOffice.

---

## 1. What DragConvert actually ships

### Working conversions

- **Image inputs that work:** JPG, PNG, HEIC, TIFF, BMP. GIF works as a single frame. WebP/AVIF may decode through ImageIO on this macOS, but there is no regression test; SVG is not reliably decoded.
- **Image outputs that work:** JPG, PNG, HEIC, TIFF, BMP, PDF.
- **Image outputs that fail although the wheel offers them:** WebP (no encoder), AVIF (the UTI is missing in `ImageConvertEngine`, though ImageIO can encode AVIF on macOS 13), SVG (input-only in the reference; not an output there either).
- **PDF inputs → outputs that work:** JPG, PNG, TIFF at 300 DPI, all pages.
- **PDF outputs offered but unsupported:** DOCX, PAGES, PPTX, XLSX, EPUB, TXT, MD.
- **Unsupported families:** documents, slides, spreadsheets, EPUB, subtitles, audio, video, archives. The capability graph shows wedges for all of them; no engine exists.
- **Extra paths we ship beyond Tangerine's advertised set:** image resize, rotate/flip, remove background, read QR, PDF split, PDF compress, batch PDF→images, images→PDF, PDF add-background, image batch crop.

### Tools that work, with caveats

| Tool | DragConvert | Tangerine 2.0.2 |
|---|---|---|
| Compress | Image: target KB or quality %, optional resize. PDF: Balanced or target size. | Also percentage reduction, presets (Balanced/Strong), video/audio compression, target size |
| Crop | Image 8-handle, presets, W/H; PDF crop all pages | Same, plus exact dimensions and batch |
| Resize | Yes | Yes (added in 2.0.2) |
| Rotate / flip | Yes | Not a headline tool; organize PDF rotates pages |
| Annotate | Text, rect, ellipse, arrow, ink | Also numbered callouts, magnifiers, images, movable annotations |
| Add BG | Colour/image, blur, padding, corners, shadow | Also gradients, ratio presets, image backgrounds |
| Redact | Manual black boxes; undo | Face/text detection, solid or blur, multiple movable areas |
| Metadata | Read-only table + strip all | Search, edit individual fields, remove all |
| Collage | Grid/row/column/featured, spacing, corners, background, canvas width | Also image fit/order and final dimensions UI |
| Photo edit | Brightness, contrast, saturation, warmth | Exposure, highlights, shadows, whites, blacks, gamma, temperature, tint, detail, dehaze, clarity, grain, noise reduction, effects |
| Remove BG / Read QR | Yes (Vision) | Read QR; no remove-background claim on the current tools page |
| PDF merge/split/organize | Yes | Yes |
| PDF compress | Yes; target-size mode rasterises and loses fields/annotations | Yes; 2.0.2 specifically fixed losing fields/annotations |
| PDF page images | Yes, 300 DPI | Yes |
| PDF text/OCR/Word/Pages/PPTX/XLSX/EPUB | No | Yes, with local OCR for scanned pages |
| Video tools | 7 wedges shown; none implemented | 10 tools: compress, join, trim, split, crop, speed, mute, snapshots, redact, metadata |
| Audio tools | 5 wedges shown; none implemented | 7 tools: compress, normalize, trim, channels, visualizer, bleep, metadata |

### Actions

All six are present: AirDrop, Float, Copy, Move, Copy Path, Terminal.

Two behavior mismatches:

- **Copy** currently opens a folder picker and copies the files there. Tangerine's Copy puts the file URLs on the clipboard so they can be pasted in Finder. This is a semantic bug, not a missing feature.
- **Terminal** always opens Terminal.app. Tangerine lets you choose Terminal or iTerm2 (and any terminal app) in Settings.

Actions work with folders and mixed selections, which matches the reference.

### Core interaction

- **Wheel hides when the modifier is released.** `DragMonitor` rebuilds `FileDragSession` with the current modifier flags; `updateWheel` calls `wheel.hide()` when `WheelMode.from` returns nil. Tangerine says: release the key and keep dragging; the wheel stays open until drop or cancel.
- **Wheel centre is text only.** `WheelView` draws the filename in an orange well. It does not draw the dragged file's thumbnail or the file-size pill that Tangerine shows.
- **Wheel is flat-drawn.** 340 pt panel, solid wedges, no glass/blur material, no spring/scale appearance animation. Tangerine uses a glassy petal wheel with a backdrop blur and a file preview.
- **Tools are not selection-aware.** `Capabilities.tools(kind:)` returns a fixed list per kind. The image wheel always shows 12 tools; the PDF wheel always shows 9; video/audio tools are shown even though they fail. Tangerine shows only tools that apply to that exact file/selection.
- **Mixed kinds are blocked for conversions.** `FileKind.commonKind` returns nil for a mixed selection; non-action modes hide the wheel. Tangerine and OpenShelf support mixed compatible selections (e.g. HEIC + PNG → JPG).
- **Default tools shortcut is wrong.** DragConvert defaults to `⇧⌘ Option+Command`. The shipping Tangerine app uses `⇧⌥ Option+Shift` (App Store description, demo video keycaps, MacGeneration, developer launch post). Tangerine's website simulator uses Command, which is inconsistent with the app.
- **File-kind bugs:** GIF is classified as an image (Tangerine treats GIF as video); PPTX/PPT are classified as documents (so they get document targets, not slide targets); RTFD and Finder text clippings are not recognized.
- **No Finder-selection path.** Tangerine's marketing mentions keyboard use, but OpenShelf has a stronger non-drag path: select files and press ⌃⌥Space. DragConvert only works mid-drag.

### Settings and packaging

| Setting | DragConvert | Tangerine 2.0.2 |
|---|---|---|
| Wheel shortcuts | Yes | Yes |
| Sound | Yes | Yes |
| Haptics | Always on, no toggle | Separate sound/haptics toggle |
| Reveal result in Finder | Optional, default off | Reveals finished files by default |
| Conflict policy | Rename or replace | Presumably rename |
| Launch at login | Yes | Likely |
| Terminal app picker | No | Yes |
| Hide menu bar | No | Yes |
| App icon / menu-bar template icon | No (text “◎”) | Yes |
| Notarization / App Store | No | Yes |
| Auto-updates | No | App Store |
| Privacy policy / licences screen | No | Privacy policy + App Store |
| Accessibility labels | Not audited | App Store says not indicated |

---

## 2. What Tangerine 2.0.2 ships that DragConvert does not

### 2.1 Formats and conversion paths

**Images**
- WebP output (and input), AVIF output, SVG input, GIF as video, PDF output. DragConvert has AVIF/WebP in the wheel but no encoder; SVG is not a reliable input; GIF is misclassified.

**Video**
- MP4, MOV, MKV, WebM, AVI, WMV, GIF; MP3/M4A audio extraction.
- Tools: compress, join, trim, split, crop, speed, mute, snapshots, redact, metadata.
- DragConvert: none.

**Audio**
- MP3, M4A, WAV, FLAC, OGG, Opus, AIFF, WMA.
- Tools: compress, normalize, trim, channels, visualizer to MP4, bleep, metadata.
- DragConvert: none.

**PDF**
- PDF → DOCX, PAGES, PPTX, XLSX, JPG, PNG, EPUB, TXT, MD.
- PDF text/Markdown extraction with **local OCR** for scanned pages.
- PDF → Word/Pages with OCR.
- PDF/A-2b converter (new in 2.0.2).
- Merge, split, organize, compress, metadata, save pages as images, add background.
- DragConvert: JPG/PNG/TIFF only; no OCR, Office, EPUB, text, PDF/A.

**Documents**
- DOCX, PAGES, Markdown, TXT, EPUB, plus RTF/RTFD/text-clipping input.
- Output: PDF, DOCX, PAGES, TXT, MD, HTML, EPUB, JPG, PNG.
- DragConvert: none.

**Slides**
- PPT/PPTX → PDF, JPG, PNG; PDF → PPTX.
- DragConvert: PPTX is misclassified as a document; no slide engine.

**Spreadsheets**
- XLSX, ODS, CSV, TSV (XLS input) → CSV, TSV, XLSX, PDF; PDF → XLSX.
- DragConvert: none.

**EPUB**
- EPUB → PDF, DOCX, PAGES, TXT, MD, HTML; PDF → EPUB.
- DragConvert: none.

**Subtitles**
- SRT/VTT → TXT, SRT, VTT.
- DragConvert: none.

**Archives**
- ZIP/TAR/GZIP (RAR input) → ZIP/TAR/GZIP; extract.
- DragConvert: none.

### 2.2 Tool depth

- **Metadata editor:** search fields, edit values, remove individual fields, remove all, save. DragConvert only reads and strips everything.
- **Photo editor:** the reference has ~15+ controls (exposure, brightness, contrast, highlights, shadows, whites, blacks, gamma, temperature, tint, dehaze, clarity, grain, noise reduction, detail/effects). DragConvert has four.
- **Annotate:** numbered callouts, magnifiers, images, movable annotations. DragConvert has five primitives.
- **Redact:** local face/text detection, solid/blur style, colour, multiple movable areas. DragConvert has manual black rectangles.
- **Compress:** percentage reduction and presets (Balanced/Strong), plus video/audio. DragConvert has target/quality only.
- **Add BG:** gradients and ratio presets; DragConvert has colour/image, blur, padding, corners, shadow but no gradient/ratio.
- **Collage:** final dimensions, image fit, order UI; DragConvert has canvas width/layout but not the full fit/order tooling.
- **Organize PDF:** “make all pages the same width” option; DragConvert does not.
- **PDF compression:** reference 2.0.2 preserves fields/annotations; DragConvert's target-size mode rasterises and loses them. Balanced mode needs a regression test.
- **PDF→image annotations:** reference 2.0.2 fixed annotation loss; DragConvert has no regression test.
- **Archive extraction:** DragConvert none.

### 2.3 Actions and settings

- Copy → clipboard (DragConvert copies to a folder).
- Terminal app picker (DragConvert hard-codes Terminal.app).
- Hide the app from the menu bar.
- Separate sound and haptic toggles.
- Stop opening the desktop folder after conversions.
- Reveal finished files in Finder by default.
- Wheel stays open after releasing the shortcut.
- File drag from Dock icons (2.0.2 fix).
- InDesign drag+Shift UI fix (2.0.2).
- iCloud Drive multi-page PDF output folder fix (2.0.2).
- Large Excel conversion fix (2.0.2).

### 2.4 Packaging

- App icon and menu-bar template icon.
- Notarized App Store distribution.
- Privacy policy and support.
- Auto-updates.
- Press kit, screenshots, demo video, product page.
- App Store listing with version history and release notes.
- The app is Apple-silicon-only; DragConvert can support Intel and macOS 13.

---

## 3. Where DragConvert is behind even on features it claims

These are more damaging than missing features because they break trust at the moment of use.

1. **The wheel lies.** WebP, AVIF, SVG, PDF→Office, documents, slides, spreadsheets, audio, video, subtitles and archives all appear as wedges but fail. A user sees 270 options and gets “Can’t convert…” on the first try. This is the top P0.
2. **The wheel disappears when the modifier is released.** Tangerine and OpenShelf keep it open. The current behavior punishes the exact deliberation the wheel is supposed to enable.
3. **The tool shortcut is wrong.** `⇧⌘` vs the shipping app's `⇧⌥`. The website says Command, the App Store/demo/MacGeneration say Option+Shift; the actual app is the tie-breaker.
4. **Copy is wrong.** It copies to a chosen folder instead of putting file URLs on the clipboard.
5. **Mixed selections are blocked.** Tangerine supports mixed selections that share a format; DragConvert hides the wheel.
6. **The wheel is visually behind.** No thumbnail, no file size, no glass, no appear motion, 340 pt vs the reference's larger petal wheel.
7. **GIF is classified as an image.** Tangerine treats GIF as video (GIF↔video, MP4→GIF).
8. **PPTX is classified as a document.** It gets document targets instead of slide targets.
9. **No selection-aware tool list.** Video/audio wedges are shown even though no engine exists; image wheels show tools that may not apply to SVG/GIF.
10. **PDF target-size compression loses annotations/fields.** The reference fixed this in 2.0.2. Balanced mode needs a test.
11. **Reveal-in-Finder is off by default.** Tangerine reveals finished files; ours makes the user hunt.
12. **Terminal is hard-coded.** The reference lets the user choose Terminal or iTerm2.
13. **No app icon or menu-bar template icon.** The menu bar shows a text “◎”.
14. **No notarization or update path.** The app is ad-hoc signed; `make run` works locally, but it is not a product someone can install normally.

---

## 4. Where DragConvert can win

These are real advantages or cheap opportunities, not consolation prizes.

- **Free and GPL-3.0.** Tangerine is $29.99 with a 20-file trial; DragConvert has no paywall, no account, no limits. OpenShelf is also free/MIT, so this is necessary but not sufficient.
- **macOS 13+ and potentially Intel.** Tangerine requires Apple silicon. A universal build widens the audience and is a credible differentiator.
- **Auditable privacy.** DragConvert has no network entitlement at all. Tangerine's privacy is a policy promise; ours is visible in the signed bundle. Keep it that way, and make the update mechanism explicit if we add one (Sparkle needs a network entitlement, which would weaken this claim).
- **Latency.** MacGeneration reported micro-lags on an M1 when Tangerine's wheel opens. A 60 Hz polled wheel with a simple native panel can potentially feel faster. Benchmark it; if true, make it a headline.
- **Keyboard-first / accessibility.** Tangerine's App Store page says no accessibility features indicated. DragConvert already supports 1–9, arrows, Return, Escape. Add VoiceOver labels and a Finder-selection path.
- **Automation.** Shortcuts actions, AppleScript, URL scheme, CLI, watch folders. Tangerine is GUI-only; OpenShelf is GUI+keyboard. A scriptable free GPL-3.0 app is a different product.
- **Truthful capability graph.** If the wheel is generated from the engine registry, it structurally cannot lie. That is a trust feature no competitor markets.
- **Open development.** Public roadmap, issues, tests, GPL-3.0 contributions. Tangerine is closed.
- **No external runtime required for the current features.** OpenShelf optionally installs FFmpeg/LibreOffice/Pandoc; DragConvert's current image/PDF stack is native. Keep the base app small and make extras optional.

---

## 5. New or changed in Tangerine 2.0.2 that our docs missed

The website and press kit are still at **v1.4**; the App Store is **v2.0.2** (29 Oct 2026). Do not treat the website's feature list as the latest app.

New/changed in 2.0.2:

- Image resize tool.
- WebM support.
- PDF/A-2b converter.
- Drag from Dock icons.
- Large Excel conversion fix.
- PDF compression preserving fields and annotations.
- PDF→image preserving annotations.
- InDesign drag+Shift UI fix.
- iCloud Drive multi-page PDF output folder fix.
- Terminal app selection setting.
- Separate sound and haptic feedback settings.
- Stop opening the desktop folder after converting a file on the desktop.
- Hide the app from the menu bar.

2.0 (14 Oct 2026) added the Actions wheel, EPUB/Word/Pages/PowerPoint/spreadsheet support, floating file shelf, and percentage compression. Our `PARITY.md` was largely based on v1.4; it is missing these.

**Shortcut inconsistency:** the website simulator and some reviews say Command for tools; the App Store description, demo video keycaps, MacGeneration review and the developer's Reddit post say Option+Shift. The shipping app is the authority. DragConvert should default to **⇧⌥ Option+Shift** and keep the customizable picker.

---

## 6. The council verdict

Five independent advisors reviewed the dossier. The consensus was unusually strong:

### Consensus

1. **Truth is the P0.** Remove every unimplemented wedge before adding engines. A wheel that only shows real options is better than a 275-path wheel that fails.
2. **Sticky wheel, ⇧⌥, Copy-to-clipboard, mixed selections, thumbnail/size, and file-kind fixes** buy more perceived parity than any new format. They are cheap and highly visible.
3. **Do not chase 275 paths.** Every family is a maintenance contract. Office/slide/spreadsheet fidelity via LibreOffice is a 600 MB, sandbox-hostile, licence-heavy trap.
4. **Build breadth only where it compounds:** WebP/AVIF/SVG first; optional FFmpeg for audio/video; PDF OCR/PDF-A as a native differentiator.
5. **Make the capability graph derive from engines** so the app cannot lie again. Add a test asserting every offered conversion resolves to a working encoder.
6. **Packaging is a product gate:** icon, menu-bar template, notarization, update path, privacy/licences.

### Contested points

- **How much breadth is enough?** The contrarian warns that a truthful but tiny app becomes “Preview with a radial menu.” The expansionist argues for optional providers to inherit breadth without maintaining it. The pragmatic answer: ship the truthful core, then add one compounding media path (optional FFmpeg) and one native PDF path (OCR/PDF-A) before considering Office.
- **Bundle vs optional dependencies.** Everyone opposed bundling LibreOffice. FFmpeg is more debatable: the contrarian calls it the best paths-per-integration; the executor says optional, user-installed only. Recommendation: optional, clearly labelled, with a one-click installer and a licence screen. Never bundle 600 MB.
- **Sparkle vs no-network.** Sparkle requires network access and would weaken the “no network entitlement” claim. Either use App Store updates, or add Sparkle with an explicit, auditable opt-in and update the privacy copy. Do not quietly add networking.

### Blind spots caught in peer review

- **Fidelity, not just coverage.** ImageIO round-trips can drop colour profiles, 16-bit depth and alpha. A working path that silently changes the image is worse than an honest “unsupported.” Add colour-profile/alpha/bit-depth fixtures.
- **Security.** Parsing untrusted files with ImageIO/PDFKit/FFmpeg/LibreOffice is an attack surface. “No network” is not “safe.” Sandboxing and process isolation matter.
- **Maintenance and demand evidence.** No one proposed a success metric or kill criterion. Add opt-in local metrics or a manual QA scorecard; do not build 275 paths on faith.
- **Sticky wheel is a lifecycle change, not a one-line patch.** Budget days, not hours.

### Council recommendation

**Ship a “Truthful Wheel” release first (about one week):**

1. Filter the capability graph to engines that exist; every offered wedge must work.
2. Make the wheel sticky until drop/Escape.
3. Default to ⇧⌥; update onboarding/settings.
4. Copy puts URLs on the clipboard; add a terminal-app picker.
5. Support mixed compatible selections; fix GIF/PPTX/RTFD classification.
6. Draw the dragged file's thumbnail and size in the centre; add appear motion.
7. Add the app icon, menu-bar template icon, and a visible “not yet” path for missing formats.

**Then two to three weeks of compounding work:**

8. WebP encode (libwebp/FFmpeg) and AVIF encode (ImageIO); SVG input; animated GIF.
9. PDF OCR → TXT/MD/DOCX/Pages; PDF/A-2b; preserve annotations/fields in compression and PDF→image.
10. Metadata editor and the deeper photo/annotate/redact controls.

**Then optional media:**

11. An optional, user-installed FFmpeg provider with a licence screen; audio/video conversions and the 12 media tools.
12. Optional Pandoc/LibreOffice providers only if demand justifies them.

**In parallel:** notarization, update channel, privacy/licences, accessibility, Intel build, and a Finder-selection/Shortcuts path.

---

## 7. Prioritized backlog

### P0 — truthful wheel (about 1 week)

| ID | Task | Acceptance | Effort |
|---|---|---|---|
| TRUTH-1 | Filter `Capabilities` by implemented engines | No wedge appears unless a test proves the conversion/tool works; unsupported families are hidden or shown as “not yet,” never as a failing action | 1–2 d |
| WHEEL-5 | Sticky wheel | Release the modifier; wheel stays until drop/Escape; tapping another mode switches wheels | 2–4 d |
| WHEEL-6 | Centre preview + motion | Dragged file thumbnail + size pill; scale/fade appearance; Reduce Motion respected | 1–2 d |
| ACT-5 | Copy + terminal semantics | Copy writes file URLs to the pasteboard; terminal picker supports Terminal/iTerm2 | 1 d |
| DRAG-3 | Mixed selections + kinds | HEIC+PNG → JPG works; GIF is video; PPTX is slides; RTFD is recognized; mixed tools show the intersection | 2–3 d |
| PKG-0 | Product gate | Icon, menu-bar template, version, notarization, update policy, privacy/licences | 3–5 d |

### P1 — image/PDF depth (2–3 weeks)

| ID | Task | Acceptance | Effort |
|---|---|---|---|
| IMG-16 | WebP/AVIF/SVG | WebP output via libwebp/FFmpeg; AVIF via ImageIO; SVG input; animated GIF handled explicitly | 3–5 d |
| PDF-10 | OCR + PDF/A | PDF→TXT/MD with Vision OCR; PDF→DOCX/Pages; PDF/A-2b; annotations/fields preserved in compression and PDF→image | 1–2 wk |
| IMG-17 | Metadata editor | Search, edit, remove individual fields, remove all; image/PDF/video/audio metadata | 3–5 d |
| IMG-18 | Photo editor depth | Exposure, highlights, shadows, whites, blacks, gamma, temperature, tint, clarity, grain, noise reduction, detail | 1 wk |
| IMG-19 | Annotate/redact depth | Numbered callouts, magnifiers, images, movable annotations; face/text detection, blur, multiple areas | 1 wk |
| PDF-11 | Compress/organize polish | Percentage reduction/presets; preserve annotations/fields; same-width pages | 3–5 d |

### P2 — optional media and document providers (4–6 weeks)

| ID | Task | Acceptance | Effort |
|---|---|---|---|
| MEDIA-1 | Optional FFmpeg provider | One-click install, licence screen, no bundled binary; video/audio conversions + trim/crop/speed/join/split/snapshots/mute/normalize/channels/bleep/visualizer | 2–3 wk |
| DOC-1 | Optional Pandoc/LibreOffice provider | Documents/slides/sheets/EPUB/subtitles/archives with clear labels and per-path QA | 2–3 wk |
| AUTO-1 | Automation | Finder selection shortcut, Shortcuts actions, URL scheme/CLI, watch folders | 1–2 wk |

### Do not build (yet)

- PDF→PPTX/XLSX high-fidelity layout reconstruction — the fidelity will be poor and the maintenance is high.
- Bundled LibreOffice — 600 MB, sandbox-hostile, licence and update burden.
- A 275-path graph maintained by hand — derive it from engines instead.
- A paywall — the app is GPL-3.0 and free; keep it that way.

---

## 8. What to tell users / put in the README

The honest positioning is stronger than the current one:

> DragConvert is a free, open-source macOS file wheel. The current release converts and edits images and PDFs locally; every wedge in the wheel is one that works. Audio, video, documents, slides, spreadsheets, EPUB, subtitles and archives are on the roadmap, with optional providers rather than a 600 MB bundle.

That is a product people can trust. The current 270-wedge graph is not.

---

## 9. Sources

- Tangerine homepage: <https://tangerineformac.com/>
- Tools page / data: <https://tangerineformac.com/tools> and `/assets/tools-DHpyoIBf.js`
- Press kit: <https://tangerineformac.com/press>, `/downloads/tangerine-press-kit.zip`
- Demo video: `/videos/tangerine-demo.mp4`
- Privacy: <https://tangerineformac.com/privacy>
- App Store: <https://apps.apple.com/us/app/tangerine-file-converter/id6813034065>
- iTunes lookup (v2.0.2 notes): <https://itunes.apple.com/lookup?id=6813034065&entity=macSoftware>
- Digital Trends, 22 Oct 2026: <https://www.digitaltrends.com/computing/tangerine-for-mac-makes-file-conversions-seamless-with-a-simple-drag-and-drop-gesture/>
- MacGeneration, 2 Oct 2026: <https://www.macg.co/logiciels/2026/10/tangerine-un-convertisseur-de-fichiers-toujours-portee-de-main-sur-mac-311381>
- Reddit launch post: <https://www.reddit.com/r/MacOS/comments/1wqo9wy/tangerine_just_hold_shift_and_drag_to_convert/>
- OpenShelf (free MIT competitor): <https://github.com/Manan-Santoki/OpenShelf>
- AppAgg version history: <https://appagg.com/macos/utilities/tangerine-file-converter-44294506.html>
- Council dossier: [`TANGERINE-RESEARCH-DOSSIER.md`](TANGERINE-RESEARCH-DOSSIER.md)
- Council transcript: [`council-transcript-20261103.md`](council-transcript-20261103.md)
- Council visual report: [`council-report-20261103.html`](council-report-20261103.html)

---

*Research note: Tangerine's website and press kit are v1.4; the App Store build is v2.0.2. Where they disagree, this report treats the shipping app and its release notes as authoritative. The $29.99 price and 20-file trial are Tangerine's, not DragConvert's; DragConvert is free and GPL-3.0-licensed.*
