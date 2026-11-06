<p align="center">
  <img src="docs/screenshots/icon.png" width="112" height="112" alt="DragConvert App Icon" />
</p>

<h1 align="center">DragConvert</h1>

<p align="center">
  <strong>Convert, edit, and manipulate files mid-drag from a radial wheel directly at your cursor.</strong><br>
  100% free, open-source (GPL-3.0), local-first, and lightning fast. No subscriptions, no telemetry, no cloud uploads.
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-blue.svg?style=flat-square" alt="GPL-3.0 License" /></a>
  <a href="https://apple.com/macos"><img src="https://img.shields.io/badge/macOS-13.0%2B-black.svg?style=flat-square&logo=apple" alt="macOS 13+" /></a>
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-6.0-orange.svg?style=flat-square&logo=swift" alt="Swift 6" /></a>
  <a href="#"><img src="https://img.shields.io/badge/architecture-Universal%20(M--series%20%2B%20Intel)-6f42c1.svg?style=flat-square" alt="Universal Binary" /></a>
  <a href="#"><img src="https://img.shields.io/badge/privacy-100%25%20Offline%20(No%20Network)-success.svg?style=flat-square" alt="Offline & Private" /></a>
  <a href="#"><img src="https://img.shields.io/badge/price-Free%20Forever-brightgreen.svg?style=flat-square" alt="Free Forever" /></a>
</p>

---

<p align="center">
  <img src="docs/screenshots/wheel.png" width="720" alt="DragConvert Radial Wheel" />
</p>

## Why DragConvert?

Every day on macOS, we switch apps, fiddle with export menus, or upload confidential documents to random web converters just to resize an image, convert a PDF, extract text, or strip camera metadata.

**DragConvert ends the friction.**

Just drag any file in Finder, tap a modifier key, and a fluid radial wheel blooms right under your cursor. Flick to a wedge and release. Your converted or edited file appears instantly **right beside the original**—with zero quality loss, zero telemetry, and zero context switching.

```
Drag file in Finder ──> Tap ⇧ / ⇧⌥ / ⌃ ──> Wheel appears anchored ──> Release on wedge ──> Done!
```

---

## The Three Wheels

Customizable shortcuts let you summon three distinct, context-aware radial wheels on demand:

| Wheel | Trigger | What it does |
|---|---|---|
| **Convert** | <kbd>⇧ Shift</kbd> | Instant format conversion (JPG, PNG, HEIC, TIFF, AVIF, BMP, PDF, TXT, Markdown). |
| **Tools** | <kbd>⇧⌥ Option + Shift</kbd> | In-place creative tools: Crop, Remove BG, Compress, Redact, Annotate, Merge, Split, Frame, Collage. |
| **Actions** | <kbd>⌃ Control</kbd> | Utility workflows: AirDrop, Floating Shelf, Copy to Clipboard, Move, Copy Path, Open in Terminal/iTerm2. |

> **Sticky Wheel:** No need to hold down keyboard shortcuts while dragging. Tap the modifier key once and release—the wheel stays pinned until you drop or press <kbd>Esc</kbd>.

---

## Key Features

### 🎯 Mid-Drag Format Conversion (`⇧ Shift`)
* **Images**: Convert between **JPG, PNG, HEIC, TIFF, BMP, and AVIF**.
* **Images → Single PDF**: Drop a multi-image selection onto the PDF wedge to instantly stitch them into an ordered, multi-page document.
* **PDF → Raster**: Renders every page of a PDF into crisp, individual **300 DPI** images (JPG, PNG, TIFF).
* **PDF → Text & Markdown with On-Device OCR**: Extracts clean selectable text streams, falling back to local **Apple Vision OCR** for scanned documents.
* **Smart Mixed Selections**: Drop mixed file types (e.g., HEIC + PNG); the wheel dynamically calculates their common target formats. Files already matching the target are safely skipped.

### 🛠️ In-Place Pro Tools (`⇧⌥ Option + Shift`)
* **Precision Crop & Batch Crop**: 8-handle interactive crop panel with aspect ratio presets (`Free`, `1:1`, `16:9`, `9:16`, `4:3`, `3:4`) and live pixel dimensions. Batch-crop an entire selection with one normalized framing.
* **Instant Background Removal**: Runs Apple Vision foreground segmentation on-device via the Neural Engine. Exports a clean, transparent PNG in milliseconds.
* **Smart Compression**: Target an exact file size (e.g. *"Hit exactly 500 KB"*) or pick a quality percentage. Iterative search never inflates files that are already small.
* **True Content Redaction**: Not just visual black boxes—flattened, destructive pixel wipe for both Images and PDFs. Underlying text and vectors are physically destroyed.
* **Complete PDF Workbench**:
  * **Merge**: Seamlessly merges multiple PDFs in the exact order you dragged them.
  * **Split**: Split by page numbers or into $N$ equal parts in an organized subfolder.
  * **Organize**: Visual thumbnail grid to drag-to-reorder, rotate in 90° increments, duplicate, or delete individual pages.
  * **Compress**: Choose between *Balanced* (keeps vector text intact) or *Target Size* modes.
  * **Crop**: Crop every page of a document simultaneously from one visual selection.
* **Add Background & Frame**: Canvas framing with customizable padding, drop shadows, corner radii, solid colors, or source image background blurs.
* **Vector Annotations**: Markup photos and PDFs with arrows, rectangles, ellipses, text, and freehand ink with customizable line weights and colors.
* **Photo Adjustments**: Live sliders for Brightness, Contrast, Saturation, and Warmth.
* **Collage Maker**: Build clean Grid, Row, Column, or Featured hero collages from multiple images.
* **Metadata Viewer & Stripper**: Inspect camera models, EXIF, IPTC, and GPS data, with a single-click clean strip for web sharing.
* **QR Code Scanner**: Decodes barcodes and QR codes on-device with immediate clipboard copy or one-click URL opening.

### ⚡ Instant File Actions (`⌃ Control`)
* **AirDrop**: Sends selection immediately via the macOS sharing service.
* **Floating Shelf**: Park files on a discreet floating desktop shelf to drag into Slack, emails, or other apps later.
* **Copy to Clipboard**: Places real file URLs directly on your system clipboard for native Finder pasting.
* **Move to Folder**: Quick destination directory picker.
* **Copy Path**: Copies newline-separated POSIX file paths.
* **Open in Terminal**: Launches the current directory in Terminal.app, iTerm2, or your configured terminal.

---

## Built for Power Users

<p align="center">
  <img src="docs/screenshots/settings.png" width="600" alt="DragConvert Settings" />
</p>

* **Full Keyboard Navigation**:
  * <kbd>1</kbd>–<kbd>9</kbd>: Instantly picks a numbered wedge.
  * <kbd>←</kbd> <kbd>→</kbd> <kbd>↑</kbd> <kbd>↓</kbd>: Cycles through options.
  * <kbd>Return</kbd>: Executes hovered tool.
  * <kbd>Esc</kbd>: Dismisses the wheel.
  * *Prevents accidental drops*: When activated via keyboard, the panel stays locked to absorb Finder’s pending mouse-up.
* **Tactile Feedback**: A soft 60 ms hover tick plus alignment haptics; separate sound and haptics toggles. The wheel blooms in 0.2 s and crossfades the hovered wedge to `#FF5200`.
* **Centre Thumbnail & Size Pill**: Shows an instant visual preview of dragged contents, file sizes, and item counts.
* **Non-Activating Floating Panel**: Never steals frontmost focus or interrupts your active workspace.
* **Atomic Writes & Collision Protection**: Writes via temporary files (`.<UUID>.tmp`) before swapping. Automatically uses smart collision naming (`sample 2.jpg`) so your original files are never overwritten.
* **Uncompromising Privacy**: Sandboxed with zero network entitlements. No phone-home telemetry, no analytics, no external servers.

---

## How It Compares

| Feature | DragConvert | Tangerine ($29.99) | Cloud Converters |
| :--- | :---: | :---: | :---: |
| **Price** | **Free & Open Source (GPL-3.0)** | $29.99 (20-file trial) | Subscription / Ad-supported |
| **Privacy** | **100% Local (0 Network Entitlement)** | Policy promise | Uploaded to remote servers |
| **Latency** | **< 80 ms (Hardware Accelerated)** | Micro-lags reported | Depends on upload/download speed |
| **Interaction** | **Radial Wheel + Keyboard (1–9)** | Radial Wheel | Drag into browser tab |
| **Architecture** | **Native Swift 6 + AppKit** | Native Swift | Web / Electron |
| **Compatibility** | **macOS 13+ (Apple Silicon & Intel)** | Apple Silicon only | Any browser |
| **Auditability** | **Full Source Available** | Closed Source | Closed Source |

---

## Installation

### Option 1: Homebrew (Recommended)

On **Homebrew 7**, trust the tap once and install:

```bash
brew trust j4yop/tap && brew install --cask j4yop/tap/dragconvert
```

On older Homebrew versions this is enough:

```bash
brew install --cask j4yop/tap/dragconvert
```

The cask installs `DragConvert.app` into `/Applications` and clears the quarantine flag automatically, so you can open it right away. If macOS still asks for confirmation, use **System Settings → Privacy & Security → Open Anyway** once.

### Option 2: Build From Source

```bash
git clone https://github.com/j4yop/DragConvert.git ~/Developer/DragConvert
cd ~/Developer/DragConvert
make install
```

`make install` builds the app, signs it with entitlements, installs it to `/Applications/DragConvert.app`, and refreshes macOS LaunchServices so the orange wheel icon appears in Spotlight and Launchpad.

### Option 3: Manual Download

Download the latest `DragConvert-*.zip` from [Releases](https://github.com/j4yop/DragConvert/releases), unzip it, and drag `DragConvert.app` into `/Applications`. The build is ad-hoc signed, not notarized; on first launch use **System Settings → Privacy & Security → Open Anyway** if macOS blocks it.

### Development Build

```bash
make run
```

Runs the application directly from the local `build/` directory.

### Live Diagnostic Logs

Curious what DragConvert sees mid-drag? Stream the real-time event pipeline:

```bash
make log
```

---

## Permissions & The App Sandbox

DragConvert is sandboxed from day one. When you drag a file into an app, macOS only grants access to that specific file—not its parent directory.

To allow DragConvert to write the converted result **right next to the original**, the app requests **Folder Access** once upon onboarding. This creates a secure, sandboxed, app-scoped bookmark stored locally in `UserDefaults`. DragConvert **never asks for Full Disk Access or Accessibility permissions**.

---

## Keyboard Reference

```
  [1] [2] [3] [4] [5] [6] [7] [8] [9]  ──> Jump directly to wedge
  [←] [→] [↑] [↓]                      ──> Cycle wedges clockwise / counter-clockwise
  [Enter / Return]                     ──> Confirm selection
  [Escape]                             ──> Cancel and dismiss wheel
```

---

## Tech Stack & Architecture

DragConvert is architected as modular Swift packages for speed, testability, and safety:

* **Swift 6 & Strict Concurrency**: Fully `@MainActor` UI with `Sendable` detached task execution.
* **DragSense**: Zero-permission 60 Hz pasteboard and modifier polling.
* **WheelUI**: Custom CoreGraphics/AppKit drawing engine for rounded annular sectors and specular highlights.
* **CapabilityGraph**: The "Truth Gate" that derives wedges strictly from verified engines.
* **JobCore**: Actor-based queue, atomic file replacement, and non-destructive naming policies.
* **Engines**: High-performance system frameworks—**ImageIO, CoreGraphics, PDFKit, and Apple Vision**.
* **57 Unit Tests**: Comprehensive coverage across format handling, redaction, compression, and math geometry.

---

## Roadmap

The core interaction loop and primary Image & PDF workflows are fully shipped. Upcoming priorities:

- [ ] **WebP & SVG Output**: Integrated WebP encoder and SVG vector rasterizer.
- [ ] **PDF/A-2b & PDF → Office**: PDF/A long-term archiving and honest DOCX/Pages conversion.
- [ ] **Optional Media Engine (FFmpeg)**: Modular, opt-in audio/video conversions and video editing tools.
- [ ] **Shortcuts & CLI Integration**: Trigger conversions and workflows without dragging.

See [PLAN.md](PLAN.md), [PARITY.md](PARITY.md), [TASKS.md](TASKS.md), and [docs/TANGERINE-GAP-REPORT.md](docs/TANGERINE-GAP-REPORT.md) for full engineering specifications and audit records.

---

## Contributing & License

Contributions, bug reports, and PRs are warmly welcomed! Please read [WORKFLOW.md](WORKFLOW.md) for our code standards, test fixtures, and quality gates.

DragConvert is free software, distributed under the **[GNU General Public License v3.0](LICENSE)** (GPL-3.0-only). You can use, study, share, and modify it; redistributed versions must remain free under the same licence. The complete corresponding source is this repository.

Relicensed from MIT to GPL-3.0 at **0.4.0**.
