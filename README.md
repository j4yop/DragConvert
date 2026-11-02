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
- Hover from the polled pointer; release fallback if the drag destination doesn't fire
- Progress HUD with running / success / failure states and cancel
- Batch selections: “3 of 5 saved”, stops on the first error
- Friendly errors for permission, disk full and missing files
- **Crop** with draggable rect, aspect presets, live pixel size, new file output
- **Resize + rotate/flip** with lock-aspect fields and a live preview
- **Compress** to a target KB or quality %, iterative, never inflates
- **Metadata** viewer (file, image, camera, dates, GPS) with one-click strip
- **PDF merge** in selection order, **split** at pages or equal parts, **organize** with a thumbnail grid (drag, rotate, duplicate, delete), **compress** Balanced or to a target KB
- PDF → JPG/PNG/TIFF at 300 DPI, all pages
- Image → JPG/PNG/HEIC/TIFF/BMP/PDF
- Atomic writes, collision naming, 28 unit tests

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
