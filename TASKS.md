# Tasks

Live backlog. IDs go in commit messages. Estimates are focused working days.

## Parity counter

| | Done | Target |
|---|---|---|
| Conversion paths | 9 | ~270 |
| Tools | 10 (crop img+PDF, resize, rotate, compress img+PDF, metadata, merge, split, organize, annotate PDF, redact PDF) | 26 |
| File actions | 0 | 6 |
| Families | 3 (image, PDF, partial docs) | 9 |
| Unit tests | 8 | 120+ |

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

**Lesson from S1:** the panel must be anchored, not follow the pointer, and the
drop must have a polled-pointer fallback because a panel that appears mid-drag
does not reliably receive `performDragOperation`.

---

## NOW — next 5 working days

- [ ] **WHEEL-1b · Appear motion** — 0.5d
  Acceptance: scale 0.86 → 1 + fade, spring 0.28/0.82, Reduce Motion = fade only.

- [ ] **S3 · Wheel performance** — 0.5d
  Acceptance: 120 fps with 10 wedges, < 8 % CPU, no memory growth after 50 opens, Reduce Transparency respected.

- [ ] **DRAG-2 · Mixed-selection notice** — 0.5d
  Acceptance: PDF + PNG shows “Pick files of one kind” in the HUD instead of no wheel; actions wheel still works.

- [ ] **IMG-1b · Batch crop** — 0.5d
  Acceptance: 5 images → crop panel for the first, same rect applied to all 5, outputs “<name> Cropped.jpg”.

- [ ] **VERIFY-2 · Keyboard mid-drag** — 0.25d ← next
  Acceptance: drag a file, hold ⇧, press 2 then Return; the chosen conversion runs, Finder’s pending drop is absorbed, and no duplicate file appears.

- [ ] **IMG-9 · Add background** — 1.5d ← next
  Acceptance: place an image on a larger canvas with padding, background colour or image, rounded corners and shadow; export as PNG; original untouched.

---

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
- [ ] **APP-1** Settings window: shortcuts, sound, reveal, conflicts — 2d
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
- [ ] **ACT-1** AirDrop — 0.5d
- [ ] **ACT-2** Float shelf — 2d
- [ ] **ACT-3** Copy / Move — 1d
- [ ] **ACT-4** Copy Path / Terminal — 0.5d

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

- [ ] **LIC-1** StoreKit 2 + trial counter — 2d
- [ ] **ONB-1** 5-step onboarding — 3d
- [ ] **ONB-2** Folder access + finish setup — 1d
- [ ] **QA-3** 40-case matrix across macOS versions — 4d
- [ ] **QA-4** Accessibility pass — 2d
- [ ] **QA-5** 500-conversion soak — 2d
- [ ] **REL-1** Privacy, support, licences, FFmpeg offer — 1d
- [ ] **REL-2** Screenshots + preview — 2d
- [ ] **REL-3** TestFlight + submission — 1d

---

## Icebox

Watch folders · recipes · AppleScript/Shortcuts · Windows · cloud · 7z · OCR by default
