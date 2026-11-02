# Tangerine vs DragConvert — research dossier

**Prepared:** 3 November 2026  
**Question:** What is DragConvert missing relative to Tangerine 2.0.2, where is it behind even on features it claims, and what should it build or fix next to be a credible free/open-source alternative?

---

## 1. Context and constraints

- **DragConvert** is a free, GPL-3.0-licensed macOS 13+ menu-bar app. Native Swift 6 + SwiftUI + AppKit. Sandboxed, ad-hoc signed, no network entitlement. 46 tests. Repo: `github.com/j4yop/DragConvert`.
- Core interaction: drag a file in Finder, hold a modifier, a radial wheel appears at the pointer, drop on a wedge, output is written beside the original.
- Three modes: Convert (⇧ Shift), Tools (currently ⇧⌘ Option+Command), Actions (⌃ Control).
- Current implementation is images and PDF only. Most other families are advertised in the capability graph but have no engine.
- The app was just made free/open source. A previous StoreKit paywall was removed.
- Distribution is not production-ready: no app icon, no menu-bar template icon, no notarization, no App Store build, no update mechanism, no privacy/licences screen.

## 2. What DragConvert actually ships

**Formats that work**
- Image input: JPG, PNG, HEIC, TIFF, BMP, GIF (first frame), and possibly WebP/AVIF decode via ImageIO; SVG is not reliably decoded.
- Image output: JPG, PNG, HEIC, TIFF, BMP, PDF. WebP, AVIF and SVG targets are offered but have no encoder.
- PDF input → JPG, PNG, TIFF (300 DPI, all pages). PDF → DOCX/Pages/PPTX/XLSX/EPUB/TXT/MD is offered but unsupported.
- Images → PDF (multi-image), PDF merge/split/organize/compress/crop/annotate/redact/add-background.
- No document, slide, spreadsheet, subtitle, archive, audio or video engine.

**Tools that work, with caveats**
- Image: Compress (target KB or quality %, optional resize), Crop (8 handles, presets, W/H), Resize, Rotate/flip, Annotate (text/rect/ellipse/arrow/ink), Add BG (colour/image, blur, padding, corners, shadow), Redact (manual black boxes), Remove BG (Vision), Metadata (read + strip all), Collage, Read QR, Edit (brightness/contrast/saturation/warmth only).
- PDF: Compress (balanced or target size; target size rasterises), Crop, Annotate (same five primitives), Redact (manual boxes, rasterised), Add BG, Metadata (read + strip), Merge, Organize, Split.
- Batch: image conversions; image crop batch; images→PDF; PDF merge; collage. Most editors still work on the first file only.
- Actions: AirDrop, Float shelf, Copy, Move, Copy Path, Terminal. **Copy actually asks for a destination folder and copies there; Tangerine's Copy puts file URLs on the clipboard.** Terminal is hard-coded to Terminal.app.
- Settings: wheel shortcut pickers, sound, reveal-in-Finder (default off), conflict naming/replace, launch at login.
- Onboarding: 5-step capsule with wheel demo, folder access, launch at login, free/open-source copy.

**Core UX facts**
- The wheel hides as soon as the modifier is released. `DragMonitor` rebuilds the session with current modifiers and `updateWheel` calls `wheel.hide()` when no mode is active.
- The wheel is a 340 pt flat-drawn panel with solid fills. It shows only the filename in the centre; no file thumbnail and no file-size pill.
- Tools are chosen by file kind, not by exact extension or selection size. The image wheel always shows 12 tools; the PDF wheel always shows 9; video/audio wheels show tools that have no engine.
- Mixed-kind selections return `unknown` for non-action modes and hide the wheel. There is no “convert these different image types to one format” flow.
- The graph misclassifies GIF as an image (Tangerine treats GIF as video), PPTX/PPT as a document (so it gets document targets, not slide targets), and lacks RTFD/text-clipping input.
- No selection-aware tool list. Tangerine only offers multi-file tools for multi-selections (compress, metadata, crop, PDF split, archive extract, create PDF, merge PDF, join video, collage).
- Keyboard: 1–9, arrows, Return, Escape work while the panel is key. No Finder-selection path without a drag.

## 3. What Tangerine 2.0.2 actually ships

- **Price/model:** $29.99 one-time, 20-file free trial, then action wheel only. Mac App Store, Apple silicon, macOS 13+. No analytics; files local. Press kit last updated at v1.4; App Store is v2.0.2 (released 29 Oct 2026). Website/press kit are partially stale.
- **Scale:** 275 conversion paths, 26 advanced tools, 6 actions, 9 families (images, video, audio, PDF, documents, slides, spreadsheets, EPUB, subtitles, archives).
- **Convert formats**
  - Images: JPG, PNG, WebP, HEIC, TIFF, AVIF, BMP, SVG input, GIF, PDF out.
  - Video: MP4, MOV, MKV, WebM, AVI, WMV, GIF; MP3/M4A audio out.
  - Audio: MP3, M4A, WAV, FLAC, OGG, Opus, AIFF, WMA.
  - PDF: DOCX, PAGES, PPTX, XLSX, JPG, PNG, EPUB, TXT, MD.
  - Documents: DOCX, PAGES, MD, TXT, EPUB (RTF, RTFD, text-clipping input) → PDF, DOCX, PAGES, TXT, MD, HTML, EPUB, JPG, PNG.
  - Slides: PPT/PPTX → PDF, JPG, PNG; PDF → PPTX.
  - Spreadsheets: XLSX, ODS, CSV, TSV (XLS input) → CSV, TSV, XLSX, PDF; PDF → XLSX.
  - EPUB: EPUB → PDF, DOCX, PAGES, TXT, MD, HTML; PDF → EPUB.
  - Subtitles: SRT/VTT → TXT, SRT, VTT.
  - Archives: ZIP/TAR/GZIP (RAR input) → ZIP/TAR/GZIP; extract.
- **Tools (26):** compress (size/percent/preset), edit metadata (search, edit, remove), edit photos (exposure/light/color/detail/effects, dehaze/clarity/grain/noise reduction), annotate (arrows, shapes, text, numbered callouts, magnifiers, images), add background (solid/gradient/image, ratio, padding, corners, shadow), crop, redact (face/text detection, solid/blur, multiple areas), collage (grid/row/column/featured, final dimensions, spacing, corners, background), video trim/crop/speed/join/split/snapshots/mute/redact/edit metadata/compress, audio normalize/trim/channels/bleep/visualizer/compress/edit metadata, PDF merge/split/organize/compress/metadata, PDF save-pages-as-images, PDF text/Markdown with OCR, PDF→Word/Pages with OCR, PDF→PPTX/XLSX/EPUB, archive extract.
- **Actions:** AirDrop, Float, Copy (clipboard), Move, Copy Path, Terminal (Terminal or iTerm2). Work with folders, mixed selections, and files with no conversion tools.
- **UX:** Shift opens conversions; **Option+Shift opens tools** (App Store description, demo video, MacGeneration, Reddit launch post). Website simulator says Command; that is inconsistent with the shipping app. The wheel stays open after releasing the shortcut until drop or Escape. The wheel centre shows the dragged file's thumbnail, name and size. Multi-file wheels show only tools valid for that selection. A small progress card appears and finished files are revealed in Finder. Settings include terminal app selection, separate sound/haptic toggles, hide menu bar, stop opening desktop folder.
- **2.0.2 new/fixed:** image resize, WebM, PDF/A-2b converter, drag from Dock icons, large Excel fix, PDF compression preserving fields/annotations, PDF→image preserving annotations, InDesign drag+Shift UI fix, iCloud multi-page PDF output folder fix.

## 4. Verified gaps, grouped

**P0 — credibility / core interaction**
1. Advertised-but-unimplemented formats: WebP/AVIF/SVG output, PDF→Office/EPUB/text, documents, slides, spreadsheets, audio, video, subtitles, archives. The wheel promises them and the HUD fails. This is the biggest trust problem.
2. Sticky wheel: release the modifier and the wheel disappears. Tangerine and OpenShelf keep it open until drop/Escape.
3. Wrong default tools shortcut: ⇧⌘ vs the shipping app's ⇧⌥.
4. Copy action is copy-to-folder, not clipboard.
5. Mixed selections and multi-file tool graph are not supported.
6. Wheel fidelity: no thumbnail/size in the centre, flat rather than glassy, no appear motion.
7. File-kind bugs: GIF as image, PPTX as document, missing RTFD/text clipping.

**P1 — table-stakes parity**
8. Image codecs: WebP, AVIF, SVG, animated GIF; conversion to PDF.
9. Media pipeline: FFmpeg LGPL for audio/video conversions and the 12 video/audio tools.
10. PDF OCR/export: Vision OCR + PDFKit/Office writers; PDF/A-2b; preserve annotations/fields.
11. Documents/slides/sheets/EPUB/subtitles/archives: Pandoc/LibreOffice or native importers; decide bundle vs optional install.
12. Tool depth: metadata editor; full photo editor; redact face/text + blur; annotate callouts/magnifiers/images; compress presets/percentage; collage dimensions/fit/order; organize PDF same-width.
13. Packaging: app icon, menu-bar template icon, privacy policy, licences, notarization/App Store, updates, hide menu bar, terminal selection, separate haptics, reveal-on-finish default.

**P2 — differentiation**
14. Keyboard-without-drag (Finder selection) path.
15. Multi-selection “only common formats” UX.
16. Optional codec installers or bundled FFmpeg/LibreOffice with a licence story.
17. Accessibility, localization, Intel support, undo/history, recipes/watch folders.

## 5. Competitive context

- **Tangerine** is polished but paid and Apple-silicon-only. Weaknesses reported by reviewers: $29.99, micro-lag on an M1 when opening the wheel, invisible-tool discoverability, feature depth unproven.
- **OpenShelf** is a free MIT competitor (`github.com/Manan-Santoki/OpenShelf`, macOS 14+) with sticky wheels, mixed selections, many formats, tools, shelves, Sparkle updates, and optional FFmpeg/LibreOffice/Pandoc installs. It is ahead of DragConvert on breadth and core wheel behavior, but requires macOS 14 and optional dependencies.
- **Open-Tangerine** is an early GPL-3.0 project, not a complete replacement.
- DragConvert's potential advantages: macOS 13+, simpler native app, no account/telemetry, GPL-3.0, likely lower memory/latency, and the ability to beat Tangerine on accessibility and transparent open-source development.

## 6. Evidence

- Tangerine homepage: https://tangerineformac.com/
- Tools detail data: https://tangerineformac.com/assets/tools-DHpyoIBf.js
- Press kit: https://tangerineformac.com/press and `/downloads/tangerine-press-kit.zip`
- Privacy: https://tangerineformac.com/privacy
- App Store: https://apps.apple.com/us/app/tangerine-file-converter/id6813034065
- iTunes lookup (v2.0.2 release notes): https://itunes.apple.com/lookup?id=6813034065&entity=macSoftware
- Digital Trends review, 22 Oct 2026: https://www.digitaltrends.com/computing/tangerine-for-mac-makes-file-conversions-seamless-with-a-simple-drag-and-drop-gesture/
- MacGeneration review, 2 Oct 2026: https://www.macg.co/logiciels/2026/10/tangerine-un-convertisseur-de-fichiers-toujours-portee-de-main-sur-mac-311381
- Reddit launch post (developer): https://www.reddit.com/r/MacOS/comments/1wqo9wy/tangerine_just_hold_shift_and_drag_to_convert/
- OpenShelf: https://github.com/Manan-Santoki/OpenShelf
- AppAgg version history: https://appagg.com/macos/utilities/tangerine-file-converter-44294506.html
