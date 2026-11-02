# Workflow

How we build this. Companion to `PLAN.md` (architecture), `PARITY.md` (scope), `TASKS.md` (backlog).

---

## 0. Where we are — 2 Nov 2026

**The riskiest assumption is proven.**

| Milestone | Result |
|---|---|
| S1 — sandboxed drag | ✅ wheel appears during a real Finder drag |
| S2 — write beside original | ✅ sandboxed write works (headless verified; GUI logged) |
| V1 — end to end | ✅ one PDF dropped on JPG produced 4 page images |

The walking skeleton has a menu-bar app, a working wheel, two real engines (PDF→raster, image→image/PDF), atomic writes, collision naming, 8 tests and CI.

**The bug that cost a day:** the wheel re-centred on the cursor every frame, trapping the pointer in the centre well. Fixed by anchoring the panel once and driving hover from the polled pointer, with a release fallback. Recorded in `TASKS.md` so it is never reintroduced.

---

## 1. Operating model

| Role | Who | Owns |
|---|---|---|
| Product + QA | You | scope, taste, real-file testing, signing, App Store |
| Implementation | Me | code, tests, fixtures, refactors, docs |
| Shared truth | `PARITY.md` | what “done” means per format/tool |

Rules:

1. No task without an acceptance criterion containing a file type and a number.
2. One vertical slice at a time.
3. Every format gets a fixture before it is called supported.
4. Scope freezes weekly; new ideas go to the Icebox.

---

## 2. Cadence

**Monday (30 min)** — pick 3–5 tasks, write the Friday demo sentence.
**Daily (15 min)** — what moved, what’s stuck, any decision.
**Friday (30 min)** — demo on real files, update the parity counter, log risks.

Sprint = 1 week.

---

## 3. Daily loop

1. Take the top `NOW` task.
2. Read its linked section in `PLAN.md` / `PARITY.md`.
3. Write the failing test first.
4. Implement the smallest thing that passes.
5. `swift build && swift test && make run`
6. Check the acceptance criterion with a real file.
7. Update `TASKS.md` + parity counter.
8. Commit.

---

## 4. Git — and a backup, because the folder vanished once

- Trunk-based; `main` always demoable.
- Branches `feat/CORE-1-hud`, `fix/…`, `spike/…`.
- Conventional commits.
- Tag demos `v0.1`, `v0.2`.
- **Push to a private GitHub repo after every session.** A local repo is not a backup; the Desktop folder disappeared with no Trash entry and no snapshot.
- Fixtures over 2 MB are generated, not committed.

---

## 5. Quality gates

- [ ] `swift build` clean, no warnings
- [ ] `swift test` green
- [ ] new capability has a fixture + property assertion
- [ ] no main-thread work > 16 ms
- [ ] no new entitlement without a note in `PLAN.md §6`
- [ ] no new dependency without a licence row
- [ ] `PARITY.md` updated
- [ ] failure path tested (cancel leaves no temp file)

Budgets: wheel ≤ 80 ms, idle CPU ≈ 0, 10 MB image ≤ 400 ms, PDF page ≤ 250 ms, idle memory ≤ 120 MB.

---

## 6. Week 2 — done and next

**Done:** output path verified, progress HUD (running/success/failure, cancel), batch selections with “N of M”, friendly error mapping, hover haptics.

| Day | Task | Demo sentence |
|---|---|---|
| ✅ Mon | **VERIFY-1** + **CORE-1** HUD | “I drop a file and see a toast with progress.” |
| ✅ Tue | **CORE-2** batch selections | “I drop 5 PDFs and see 3 of 5.” |
| ✅ Wed | **CORE-3** errors + **WHEEL-1a** haptics | “A corrupt file explains itself.” |
| → Thu | **WHEEL-1b** appear motion + **S3** performance | “10 wedges at 120 fps, no leaks.” |
| → Fri | **DRAG-2** mixed selection + demo | “A mixed selection tells me what to do.” |

**Image tools and the first PDF tools are done:** crop, resize, rotate, compress, metadata, PDF merge and PDF split. Keyboard navigation, crop polish and image Add BG are done. Next: verify keyboard during a real Finder drag, then image redact/annotate and batch crop.

**Blocked decision:** keyboard navigation (**WHEEL-2**) needs either Input Monitoring (listen-only event tap) or activating the panel (loses Finder focus). Decide in week 3; do not let it block the image tools.

---

## 7. Weeks 3–6

| Week | Focus | Demo sentence |
|---|---|---|
| 3 | Crop, resize, rotate, compress target size | “I crop to 1:1 at 1600 px and hit 500 KB.” |
| 4 | PDF merge, split, organize, crop | “I merge 3 PDFs and reorder pages.” |
| 5 | WebP/AVIF/SVG, metadata read/strip, QR | “HEIC → WebP with GPS stripped.” |
| 6 | Hardening, fixtures, accessibility | “40-case QA script green.” |

After week 6: ~85 paths, ~10 tools, loop trustworthy.

---

## 8. Definition of done

- works with 1 file and N files of the same kind
- works from Finder, Desktop, iCloud
- cancel leaves no temp file or partial output
- failure has a human sentence + recovery action
- unit test + real fixture
- VoiceOver label + keyboard path
- added to the QA script
- `PARITY.md` updated

---

## 9. Handing work to me

```
Task: IMG-1 (crop)
Context: PLAN.md §4.3, PARITY.md §3 #6
Acceptance: 5184×3456 JPEG → 1:1 → 1600×1600, saved as "<name> Cropped.jpg",
            original untouched, works on 5 files.
Constraints: no new dependency; reuse the wheel panel.
Run: swift test && make run
```

I return the diff, test output, a manual QA checklist and any plan updates.

---

## 10. Decisions

| # | Decision | Reversible? |
|---|---|---|
| D1 | Native Swift/AppKit, not Tauri/Electron | No |
| D2 | No Accessibility permission; polled drop target | Yes |
| D3 | App Sandbox + home-folder bookmark | Yes |
| D4 | FFmpeg LGPL-only for A/V | Yes |
| D5 | macOS 13+ | Yes |
| D6 | Core launch ~week 15, parity ~week 26 | Yes |
| D7 | $29.99 one-time, 20-file trial | Yes |
| D8 | Ad-hoc signing now, $99 at distribution | No |

---

## 11. Open questions

1. **Name** — DragConvert is a working title. Candidates: Pinwheel, Spoke, Fandrop, Wisp. Trademark check before the icon.
2. **Minimum macOS** — 13 (parity) or 14 (better APIs)?
3. **PAGES output** — build the iWork writer or defer?
4. **FFmpeg** — legal review now or defer A/V to v1.1?
5. **Distribution** — MAS, direct, or both?
6. **Where did the GUI outputs go?** VERIFY-1 will show the full path in the log.
