# Parity matrix — reference app vs our build

Sources: the supported-formats screenshot, `tangerineformac.com` (homepage + `/tools` JS bundle), the press kit, the App Store listing, and the eight demo recordings.

Legend: **✅** shipped · **➕** planned · **⚠️** fidelity caveat · **⏳** later phase · **❌** not doing

---

## 1. The numbers

| Metric | Reference | Our target |
|---|---|---|
| Conversion paths | 275 | ~270 |
| File tools | 26 (22 generic + 4 PDF variants) | 26 advertised + 8 extras |
| File actions | 6 | 6 |
| File families | 9 | 9 |
| Price | $29.99 one-time, 20-file trial | match |

---

## 2. Formats

### 2.1 Images

| | |
|---|---|
| Input | JPG, PNG, WebP, HEIC, TIFF, AVIF, BMP, **SVG (input only)**, GIF |
| Output | JPG, PNG, WebP, HEIC, TIFF, AVIF, BMP, **PDF** |
| Reference note | “PDF export · SVG input only” |
| Engine | ImageIO · libwebp · libavif · resvg |
| Status | ✅ JPG/PNG/HEIC/TIFF/BMP/PDF · ⏳ WebP/AVIF/SVG |

### 2.2 Audio

| | |
|---|---|
| Input / Output | MP3, M4A, WAV, FLAC, OGG, Opus, AIFF, WMA |
| Engine | AVFoundation (M4A/WAV/AIFF) · FFmpeg (MP3/FLAC/OGG/Opus/WMA) |
| Caveat | macOS has no native MP3 encoder; FFmpeg or LAME is mandatory |
| Status | ⏳ P2 |

### 2.3 Video

| | |
|---|---|
| Input | MP4, MOV, MKV, WebM, AVI, WMV, GIF |
| Output | MP4, MOV, MKV, WebM, AVI, WMV, GIF, **MP3** |
| Engine | AVFoundation + VideoToolbox · FFmpeg for MKV/WebM/AVI/WMV |
| Status | ⏳ P2 |

### 2.4 PDF

| | |
|---|---|
| Input | PDF |
| Output | **DOCX, PAGES, PPTX, XLSX**, JPG, PNG, EPUB, TXT, MD |
| Reference note | “All pages · images at 300 DPI” |
| Status | ✅ JPG/PNG/TIFF · ⏳ DOCX/PAGES/PPTX/XLSX/EPUB/TXT/MD |

### 2.5 Documents

| | |
|---|---|
| Input | DOCX, PAGES, Markdown, TXT, EPUB, **RTF, RTFD, text clippings**, HTML |
| Output | DOCX, **PAGES**, Markdown, TXT, EPUB, **HTML**, PDF |
| Status | ⏳ P3 (DocModel) |

### 2.6 Slides

| | |
|---|---|
| Input | PPT, PPTX |
| Output | PDF, JPG, PNG |
| Reference note | “PPT input only · PDF to PPTX” |
| Status | ⏳ P3 (scoped PPTX renderer, no LibreOffice) |

### 2.7 Spreadsheets

| | |
|---|---|
| Input | XLSX, ODS, CSV, TSV, **XLS (input only)** |
| Output | CSV, TSV, XLSX, PDF |
| Status | ⏳ P3 |

### 2.8 Subtitles

| | |
|---|---|
| Input | SRT, VTT |
| Output | TXT (+ SRT ⇄ VTT) |
| Status | ⏳ P3 |

### 2.9 Archives

| | |
|---|---|
| Input | ZIP, TAR, GZIP, **RAR (input only)** |
| Output | ZIP, TAR, GZIP |
| Status | ⏳ P2 (libarchive) |

---

## 3. Tools (26)

### Any file

| # | Tool | Reference behaviour | Implementation | Phase |
|---|---|---|---|---|
| 1 | **Compress** | target a file size or % reduction; resize while compressing | quality/dimension search; PDF downsample; A/V bitrate search | P1 img/PDF · P2 A/V |
| 2 | **Edit metadata** | inspect, change, remove; grouped fields; strip camera data | EXIF/IPTC/XMP, PDF info, ID3/MP4 atoms | P1 read/strip · P3 edit |

### Images

| # | Tool | Reference behaviour | Implementation | Phase |
|---|---|---|---|---|
| 3 | **Edit photos** | dehaze, clarity, grain, noise reduction, light/colour/detail, live preview | Core Image graph + `MTKView` | P4 |
| 4 | **Annotate** | arrows, text, shapes, callouts, numbered labels, magnifiers, images | vector layer → CoreGraphics | P3 |
| 5 | **Add background** | canvas, image bg, blur, rounded corners, shadow | canvas compositor | P3 |
| 6 | **Crop** | exact px; preset/custom ratios | the crop panel from the video | **P1** |
| 7 | **Redact** | solid/blur; detect faces and text; multiple areas | Vision face + text detection | P3 |
| 8 | **Collage** | grid/row/column/featured; spacing, corners, background | layout solver + renderer | P4 |

### Video

| # | Tool | Reference behaviour | Implementation | Phase |
|---|---|---|---|---|
| 9 | **Trim** | frame-accurate timecodes | FFmpeg trim | P2 |
| 10 | **Crop** | exact dimensions, keep audio | FFmpeg crop, audio copy | P2 |
| 11 | **Speed** | pitch-preserving | `setpts` + `atempo` | P2 |
| 12 | **Join** | mix MP4/MOV/MKV; first clip canvas | normalise → concat | P2 |
| 13 | **Save frames** | full-res PNG | AVAssetImageGenerator / FFmpeg | P2 |
| 14 | **Split** | points or equal parts | segment muxer | P2 |
| 15 | **Redact** | per-area time ranges | drawbox/delogo with enable | P3 |

### Audio

| # | Tool | Reference behaviour | Implementation | Phase |
|---|---|---|---|---|
| 16 | **Normalize** | loudness + true peak | `loudnorm` two-pass | P2 |
| 17 | **Visualizer** | waveform/still → MP4 | CoreGraphics frames + AVAssetWriter | P4 |
| 18 | **Trim** | silence ends, exact times | `silencedetect` + trim | P2 |
| 19 | **Channels** | mono/stereo, L/R gain, solo | `pan` | P2 |
| 20 | **Bleep** | movable range, compare | volume 0 / tone over range | P2 |

### PDF

| # | Tool | Reference behaviour | Implementation | Phase |
|---|---|---|---|---|
| 21 | **Merge** | selection order, reorder | PDFKit insert | **P1** |
| 22 | **Organize pages** | reorder, rotate, duplicate, remove | PDFKit page list | **P1** |
| 23 | **Annotate PDF** | markup on pages | PDFKit annotations | P3 |
| 24 | **Redact PDF** | remove underlying content | rasterise or rewrite content stream | P3 |
| 25 | **Add BG to PDF** | composite onto a canvas | render + composite | P3 |
| 26 | **Crop PDF** | visible page box | crop/media box | **P1** |

Extras we ship beyond the advertised 26: resize, rotate, remove background, read QR, split PDF, compress PDF, batch PDF→images, images→PDF.

---

## 4. File actions (6)

| Action | Implementation | Phase |
|---|---|---|
| AirDrop | `NSSharingService(.sendViaAirDrop)` | P2 |
| Float | floating shelf panel, drag-out | P2 |
| Copy / Move | destination picker + undo | P2 |
| Copy Path | pasteboard | P2 |
| Terminal | `NSWorkspace` + default terminal | P2 |

Actions work with folders and mixed selections and don’t consume the trial allowance.

---

## 5. Fidelity tiers

| Tier | Meaning | Applies to |
|---|---|---|
| **A — exact** | pixel/byte-accurate for the operation | image raster, A/V transcode, archives, PDF page ops |
| **B — structural** | text, headings, lists, tables, images preserved; layout approximated | DOCX/PPTX/XLSX/EPUB/MD/HTML, PDF→Office |
| **C — best-effort** | opens correctly, fidelity not guaranteed | PAGES output, PPTX SmartArt, PDF→XLSX tables |

Every tool’s UI states its tier in one line.

---

## 6. Current coverage

| Family | Paths | Status |
|---|---|---|
| Images | 6 of ~65 | 🟡 JPG/PNG/HEIC/TIFF/BMP/PDF |
| PDF | 3 of 9 | 🟡 JPG/PNG/TIFF |
| Documents | 0 | ⏳ |
| Slides | 0 | ⏳ |
| Spreadsheets | 0 | ⏳ |
| Audio | 0 | ⏳ |
| Video | 0 | ⏳ |
| Subtitles | 0 | ⏳ |
| Archives | 0 | ⏳ |
| **Total** | **9 of ~270** | **3 %** |

Tools shipped: 0 of 26. Actions shipped: 0 of 6.
