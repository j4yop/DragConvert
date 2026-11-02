# Tasks

Live backlog. IDs go in commit messages. Estimates are focused working days.

## Parity counter

| | Done | Target |
|---|---|---|
| Conversion paths | ~42 working image/PDF paths | ~270 |
| Tools | 17 implementations + PDF text/OCR | 26 |
| File actions | 6 (Copy to clipboard, terminal picker) | 6 |
| Families | 2 of 9 (images, PDF) | 9 |
| Unit tests | 57 | 120+ |

---

## DONE

- [x] **CORE-0** SwiftPM workspace, app target, local packages
- [x] **DRAG-1** Drag monitor: pasteboard + button + modifiers, no Accessibility permission
- [x] **WHEEL-0** Non-activating panel, geometry, hit-testing, drop
- [x] **CAP-0** Capability graph for 9 families, own-format exclusion, 10-wedge cap
- [x] **JOB-0** Job model, atomic write, collision naming
- [x] **IMG-0** ImageIO: JPG/PNG/HEIC/TIFF/BMP → JPG/PNG/HEIC/TIFF/BMP/PDF
- [x] **PDF-0** PDF → JPG/PNG/TIFF at 300 DPI, all pages
- [x] **APP-0** Menu bar, welcome, folder access, headless harness, signed bundle
- [x] **QA-0** Unit tests, fixture generator, CI
- [x] **S1** Sandboxed drag works: wheel appears, drop returns the file
- [x] **S2** Sandboxed write beside the original works
- [x] **V1** PDF → 4 JPGs through the wheel in one drop
- [x] **VERIFY-1** GUI output path confirmed: `/Users/jaygopal/Desktop/APCTT… 1.jpg`
- [x] **CORE-1 · Progress HUD** — running, success and failure states; cancel; auto-dismiss
- [x] **CORE-2 · Batch selections** — one HUD, per-file “N of M”, stops on error, cancel
- [x] **CORE-3 · Error surfacing** — friendly mapping for permission, disk full, missing file
- [x] **WHEEL-1a · Hover haptics** — alignment feedback on wedge change
- [x] **IMG-1 · Crop panel** — image preview, dark scrim, 4 corner handles, aspect presets, live W/H px, Reset/Apply, writes “<name> Cropped.<ext>”; engine covered by 2 tests
- [x] **IMG-2 · Resize + rotate** — “Adjust Image” window: W/H px with lock aspect, 90° left/right, flip H/V, live preview, Reset/Apply; writes “Resized”, “Rotated” or “Edited”; 4 engine tests
- [x] **IMG-3 · Compress to target size** — target KB or quality %, iterative JPEG/HEIC search, optional downscale, never inflates, copies when already smaller; 3 engine tests
- [x] **IMG-6 · Metadata read + strip** — table of file/image/camera/dates/location fields, GPS warning, “Strip Metadata” writes an upright clean copy; 3 tests
- [x] **PDF-1 · Merge** — selection order preserved, page count is the sum, output “<first> Merged.pdf”; engine test
- [x] **PDF-2 · Split** — at page numbers or equal parts, outputs to “<name> Split/part N.pdf”; 2 engine tests
- [x] **PDF-3 · Organize pages** — thumbnail grid, drag to reorder, rotate/duplicate/delete, saves “<name> Organized.pdf”; 2 engine tests
- [x] **PDF-4 · Compress** — Balanced (keeps text) or Target size (rasterises, binary ladder), never inflates; 3 engine tests
- [x] **PDF-5 · Crop** — draggable box on page 1, aspect presets, applies the same normalised crop to every page; 2 engine tests
- [x] **PDF-6 · Images → PDF** — multi-image drop on the convert wheel’s PDF target builds one PDF, one page per image in selection order; engine test
- [x] **PDF-7 · Annotate PDF** — text, rect, ellipse, arrow, ink, colour well, page navigation, undo, saves “<name> Annotated.pdf”; engine test
- [x] **PDF-8 · Redact PDF** — draw boxes, rasterise + black out, true content removal (no selectable text survives), saves “<name> Redacted.pdf”; test proves text is gone
- [x] **WHEEL-2 · Keyboard navigation** — keyable non-activating panel + local keyDown monitor; 1–9, arrows, Return, Escape; locked absorb state; verified key status without changing the frontmost app
- [x] **IMG-8 · Crop polish** — 8 handles (corners + edges), editable W/H fields with aspect preservation, downscaled preview for fast open on large images
- [x] **IMG-9 · Add background** — colour or image background, blur, padding, rounded corners, shadow, live preview, PNG/JPG; 2 engine tests
- [x] **IMG-10 · Redact images** — drag black boxes, Undo, live count, exports a copy with the pixels replaced; engine test
- [x] **IMG-11 · Annotate images** — text, rect, ellipse, arrow, ink, colour, undo, flattened export; engine test
- [x] **IMG-1b · Batch crop** — one relative crop applied to every selected image, each output beside its source; engine test
- [x] **IMG-12 · Collage** — grid/row/column/featured layouts, spacing, rounded corners, background, live preview; engine test
- [x] **IMG-13 · Remove background** — Vision foreground instance mask, transparent PNG, on-device; verified on a real portrait (alpha 0 corners, 255 subject)
- [x] **IMG-14 · Read QR** — Vision barcode decode, copyable result panel, Open Link for a URL; generated-QR test
- [x] **PDF-9 · Add background to PDF** — frame every page on a colour or image canvas with padding and shadow, export a new PDF; engine test
- [x] **IMG-15 · Photo editor** — brightness, contrast, saturation and warmth sliders, live preview, exported copy; 2 engine tests
- [x] **ONB-1 · 5-step onboarding** — capsule window, animated wheel highlight, Shift/⇧⌥/⌃ keycaps, folder access, launch at login, Done; page dots
- [x] **ONB-2 · Folder access + finish setup** — permission button, toggle, open-source copy
- [x] **ACT-1 · Actions wheel** — AirDrop, Float shelf (drag-out rows), Copy, Move, Copy Path, Terminal; transfer engine test
- [x] **APP-1 · Settings** — wheel shortcut pickers, sound, reveal in Finder, conflict policy (rename/replace), launch at login; persisted and applied live
- [x] **OPEN-1 · Free and open source** — removed the StoreKit trial/paywall; GPL-3.0 licence; onboarding and Settings say free, no limits
- [x] **TRUTH-1 · Truthful capability graph** — conversion wedges are filtered by real engines; tools are filtered by format and selection; unsupported families show a note instead of a failing action
- [x] **WHEEL-5 · Sticky wheel** — release the modifier and keep dragging; the wheel stays until drop/Escape; tested with a simulated drag
- [x] **WHEEL-6 · Centre preview** — dragged-file thumbnail, filename, size pill, rounded petals, hover colour and scale/fade appearance
- [x] **ACT-5 · Copy + terminal** — Copy writes file URLs to the clipboard; Move keeps the folder picker; Terminal has an installed-app picker
- [x] **DRAG-3 · Mixed selections + kinds** — HEIC+PNG and image+PDF convert to their shared formats; GIF is video; PPTX is slides; RTFD/text clipping recognized
- [x] **PKG-0 · Product identity** — app icon, template menu-bar wheel, About/privacy/licences, browser update link, notarization script and packaging doc
- [x] **IMG-16a · AVIF export** — ImageIO encoder + wheel target; headless conversion verified

**Lesson from S1:** the panel must be anchored, not follow the pointer, and the
drop must have a polled-pointer fallback because a panel that appears mid-drag
does not reliably receive `performDragOperation`.

---

## AUDIT — 3 November 2026

Full report: `docs/TANGERINE-GAP-REPORT.md`. The wheel currently advertises
formats with no engine. Fix truth before breadth.

### P0 — truthful wheel (shipped)
- [x] **TRUTH-1 · Truthful capability graph** — conversion + tool filtering, unsupported-family note
- [x] **WHEEL-5 · Sticky wheel** — release the modifier, wheel stays; simulated-drag QA
- [x] **WHEEL-6 · Centre preview + motion** — thumbnail, filename, size, rounded petals, hover, appear motion
- [x] **ACT-5 · Copy + terminal semantics** — clipboard URLs; Terminal/iTerm2 picker
- [x] **DRAG-3 · Mixed selections + kinds** — shared formats, GIF/PPTX/RTFD fixes
- [x] **PKG-0 · Product gate** — icon, menu-bar icon, About/privacy/licences, update link, notarization script/docs

### P1 — image/PDF depth
- [ ] **IMG-16b · WebP/SVG** — 2–3d ← next
  Acceptance: WebP encode via a bundled encoder (not a Homebrew path); SVG input and rasterisation; no failing wedges.
- [ ] **PDF-10b · PDF/A-2b + Office export** — 1–2wk
  Acceptance: PDF/A-2b output; PDF→DOCX/Pages; PPTX/XLSX/EPUB only where the fidelity is honest.
- [ ] **IMG-17 · Metadata editor** — 3–5d
  Acceptance: search fields, edit values, remove individual fields, remove all.
- [ ] **IMG-18 · Photo editor depth** — 1wk
  Acceptance: exposure, highlights, shadows, whites, blacks, gamma, temperature, tint, clarity, grain, noise reduction, detail.
- [ ] **IMG-19 · Annotate/redact depth** — 1wk
  Acceptance: numbered callouts, magnifiers, images; face/text detection, blur, multiple movable areas.
- [ ] **PDF-11 · Compress/organize polish** — 3–5d
  Acceptance: percentage/presets; preserve annotations/fields; same-width pages.

### P2 — optional media/documents (4–6 weeks)
- [ ] **MEDIA-1 · Optional FFmpeg provider** — 2–3wk
- [ ] **DOC-1 · Optional Pandoc/LibreOffice provider** — 2–3wk
- [ ] **AUTO-1 · Finder selection + Shortcuts/CLI** — 1–2wk

**Built in 0.3.0:** truth gate, sticky wheel, ⇧⌥, Copy clipboard, mixed selections, GIF/PPTX/RTFD, centre preview, app icon/menu bar/About/privacy/update, AVIF export, PDF→TXT/MD with local OCR, PDF annotation regression tests.

**Do not build:** bundled LibreOffice, high-fidelity PDF→PPTX/XLSX, a hand-maintained 275-path graph, or a paywall.

---

## NEXT — 5 working days

- [ ] **IMG-16b · WebP/SVG** — 2–3d ← next
  Acceptance: WebP encode via a bundled encoder (not a Homebrew path); SVG input and rasterisation; no failing wedges.
- [ ] **PDF-10b · PDF/A-2b + Office export** — 1–2wk
  Acceptance: PDF/A-2b output; PDF→DOCX/Pages; PPTX/XLSX/EPUB only where the fidelity is honest.
- [ ] **IMG-17 · Metadata editor** — 3–5d
  Acceptance: search fields, edit values, remove individual fields, remove all.
- [ ] **IMG-18 · Photo editor depth** — 1wk
  Acceptance: exposure, highlights, shadows, whites, blacks, gamma, temperature, tint, clarity, grain, noise reduction, detail.
- [ ] **VERIFY-2 · Keyboard mid-drag** — 0.25d
  Acceptance: drag a file, hold ⇧, press 2 then Return; the chosen conversion runs, Finder’s pending drop is absorbed, and no duplicate file appears.
- [ ] **S3 · Wheel performance** — 0.5d
  Acceptance: 120 fps with 10 wedges, < 8 % CPU, no memory growth after 50 opens, Reduce Transparency respected.

---

## Archived phase plan (superseded by the AUDIT section)

## P1 — core (weeks 2–6)

### Images
- [ ] **IMG-1** Crop panel: Free/1:1/16:9/9:16/4:3/3:4, W/H px, Reset/Apply — 2d
- [ ] **IMG-2** Resize (px + %) and rotate/flip — 1d
- [ ] **IMG-3** Compress to target size or % — 2d
- [ ] **IMG-4** libwebp + libavif: WebP/AVIF encode — 2d
- [ ] **IMG-5** resvg: SVG input at 1×/2×/4× — 1.5d
- [ ] **IMG-6** Metadata read + strip, GPS badge — 2d
- [ ] **IMG-7** Read QR — 0.5d

### PDF

### App + QA
- [ ] **APP-2** Launch at login — 0.5d
- [ ] **APP-3** History with retry — 1.5d
- [ ] **APP-4** App icon + menu bar template icon — 1d
- [ ] **WHEEL-3** “More…” wedge for >10 capabilities — 1d
- [ ] **WHEEL-4** Real glass material + specular stroke — 1.5d
- [ ] **WHEEL-5** Snapshot tests 4/6/10 wedges — 1d
- [ ] **QA-1** Fixture corpus: 120 files — 2d
- [ ] **QA-2** Property tests per engine — 2d

---

## P2 — media (weeks 7–12)

- [ ] **AUD-1** FFmpeg LGPL build + runner — 4d (legal gate)
- [ ] **AUD-2** 8 audio formats in/out — 2d
- [ ] **AUD-3** Normalize — 1.5d
- [ ] **AUD-4** Trim + silence detection — 2d
- [ ] **AUD-5** Channels — 1d
- [ ] **AUD-6** Bleep — 1.5d
- [ ] **AUD-7** Visualizer → MP4 — 3d
- [ ] **VID-1** Video convert + MP3 — 3d
- [ ] **VID-2** Trim — 1.5d
- [ ] **VID-3** Crop — 1d
- [ ] **VID-4** Speed — 1.5d
- [ ] **VID-5** Join — 2d
- [ ] **VID-6** Split — 1.5d
- [ ] **VID-7** Save frames — 1d
- [ ] **VID-8** Redact — 3d
- [ ] **ARC-1** Archives — 1d

---

## P3 — structural (weeks 13–18)

- [ ] **DOC-1** DocModel — 4d
- [ ] **DOC-2** DOCX import/export — 4d
- [ ] **DOC-3** PDF → DOCX — 3d
- [ ] **DOC-4** RTF/RTFD/clippings in, HTML out — 2d
- [ ] **DOC-5** EPUB — 2d
- [ ] **DOC-6** PAGES export (go/no-go first) — 4d
- [ ] **SHEET-1** XLSX/ODS/CSV/TSV — 3d
- [ ] **SHEET-2** XLS input — 2d
- [ ] **SHEET-3** Sheet picker + inference — 1.5d
- [ ] **SLIDE-1** PPTX renderer — 6d
- [ ] **SLIDE-2** PDF → PPTX — 2d
- [ ] **PDFX-1** PDF → PPTX/XLSX/PAGES — 5d
- [ ] **PDFX-2** Table extraction — 3d
- [ ] **SUB-1** SRT/VTT — 1d

---

## P4 — advanced (weeks 19–23)

- [ ] **IMGX-1** Photo editor — 5d
- [ ] **IMGX-2** Annotate — 4d
- [ ] **IMGX-3** Add background — 2d
- [ ] **IMGX-4** Redact photos — 3d
- [ ] **IMGX-5** Collage — 3d
- [ ] **IMGX-6** Remove background — 2d
- [ ] **IMGX-7** Metadata editor — 3d

---

## P5 — polish + launch (weeks 24–26)

- [ ] **QA-3** 40-case matrix across macOS versions — 4d
- [ ] **QA-4** Accessibility pass — 2d
- [ ] **QA-5** 500-conversion soak — 2d
- [ ] **REL-1** Privacy, support, licences, FFmpeg offer — 1d
- [ ] **REL-2** Screenshots + preview — 2d
- [ ] **REL-3** TestFlight + submission — 1d

---

## Icebox

Watch folders · recipes · AppleScript/Shortcuts · Windows · cloud · 7z · OCR by default
