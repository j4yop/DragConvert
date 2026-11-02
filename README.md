# DragConvert

A macOS utility that converts files mid-drag, from a radial wheel at the pointer.

**Status: the core loop works.** A sandboxed app sees a Finder drag, shows the wheel, and writes the converted file beside the original.

## Run

```bash
cd ~/Developer/DragConvert
make run
```

Drag a file in Finder, hold **⇧**, move the pointer outward to a wedge, release.

```bash
make log     # drag / hover / drop / job — with full output paths
```

## What works

- Menu-bar app, sandboxed, ad-hoc signed
- Wheel appears on ⇧ / ⌥⌘ / ⌃ and stays anchored
- Keyboard: 1–9 picks a wedge, arrows cycle, Return applies, Escape cancels
- Hover from the polled pointer; release fallback if the drag destination doesn't fire
- Progress HUD with running / success / failure states and cancel
- Batch selections: “3 of 5 saved”, stops on the first error
- Friendly errors for permission, disk full and missing files
- **Crop** with 8 handles, editable W/H, aspect presets, live pixel size, new file output
- **Resize + rotate/flip** with lock-aspect fields and a live preview
- **Compress** to a target KB or quality %, iterative, never inflates
- **Metadata** viewer (file, image, camera, dates, GPS) with one-click strip
- **PDF merge** in selection order, **split** at pages or equal parts, **organize** with a thumbnail grid, **compress** Balanced or to a target KB, **crop** all pages from one drag
- **Images → PDF** by dropping a multi-image selection on the convert wheel’s PDF target
- **Annotate PDF** with text, rectangles, ellipses, arrows and freehand ink, page by page
- **Redact PDF** with true content removal: pages are flattened and anything under a box is gone
- **Add BG** for images: padding, colour or image background, blur, rounded corners, shadow
- **Redact images** with black boxes, Undo and a pixel-replaced export
- **Annotate images** with the same text/shapes/ink tools as PDF
- **Batch crop** one relative crop across a whole selection
- **Collage** with grid, row, column and featured layouts
- **PDF Add BG** to frame every page on a colour or image canvas
- **Remove BG** via Vision’s on-device foreground mask → transparent PNG
- **Read QR** and copy the decoded value or open its link
- **Edit photos** with brightness, contrast, saturation and warmth + live preview
- **5-step capsule onboarding** with wheel demo, folder access and launch at login
- PDF → JPG/PNG/TIFF at 300 DPI, all pages
- Image → JPG/PNG/HEIC/TIFF/BMP/PDF
- Atomic writes, collision naming, 43 unit tests

Private repo: <https://github.com/j4yop/DragConvert>

## Read in this order

| File | What it is |
|---|---|
| **[WORKFLOW.md](WORKFLOW.md)** | Cadence, quality gates, next week, decisions |
| **[TASKS.md](TASKS.md)** | Live backlog with IDs and acceptance criteria |
| **[PARITY.md](PARITY.md)** | Feature matrix: 9 families, ~270 paths, 26 tools |
| **[PLAN.md](PLAN.md)** | Architecture, stack, risks, schedule |

## Commands

```bash
make test
make run
make log
make convert file="/path/Page 001.pdf" to=jpg
make open      # needs: brew install xcodegen
```

## Next

Progress HUD, batch selections, error surfacing, motion + keyboard, performance. Then crop.
