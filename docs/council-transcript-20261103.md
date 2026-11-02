# Council transcript — Tangerine parity and DragConvert's next move

**Date:** 3 November 2026  
**Question:** DragConvert is a free MIT macOS 13+ app with a strong core drag-wheel but only images/PDF implemented. It currently advertises many formats it cannot convert. What is the highest-leverage plan to become a credible alternative to Tangerine 2.0.2 without trying to match all 275 paths at once? Identify the P0 gaps, what to hide/fix/build first, and where DragConvert can beat Tangerine rather than merely catch up.

**Method:** Deep research dossier; five independent advisors with distinct lenses; two anonymous peer reviews; chairman synthesis. The dossier is in [`TANGERINE-RESEARCH-DOSSIER.md`](TANGERINE-RESEARCH-DOSSIER.md); the full gap report is in [`TANGERINE-GAP-REPORT.md`](TANGERINE-GAP-REPORT.md).

---

## Research dossier (summary)

- **DragConvert today:** free MIT, native Swift 6/AppKit, sandboxed, no network, 46 tests. Ships images + PDF only. The capability graph advertises ~270 paths across 9 families, but many have no engine. Core UX gaps: wheel hides on modifier release, tools shortcut is ⇧⌘ instead of ⇧⌥, Copy copies to a folder instead of the clipboard, mixed selections are blocked, GIF/PPTX are misclassified, and the wheel centre has no thumbnail/size.
- **Tangerine 2.0.2:** $29.99 one-time, 20-file trial, macOS 13+, Apple silicon only, App Store. 275 paths, 26 tools, 6 actions across images, video, audio, PDF, documents, slides, spreadsheets, EPUB, subtitles, archives. Ships OCR for scanned PDFs, PDF/A-2b, metadata editing, full photo editor, face/text redaction, video/audio tools, optional terminal selection, hide-menu-bar, separate sound/haptics, and sticky, selection-aware wheels.
- **Website vs app:** Tangerine's site/press kit are v1.4; the App Store is v2.0.2 (29 Oct 2026). The site simulator says Command for tools, but the shipping app, demo video, MacGeneration and the developer's launch post say Option+Shift. Treat the shipping app as authoritative.
- **Competition:** OpenShelf is a free MIT competitor with sticky wheels, mixed selections, broad formats, shelves, Sparkle updates and optional FFmpeg/LibreOffice/Pandoc installers (macOS 14+). DragConvert's edge must be macOS 13+, a smaller native app, auditable no-network privacy, and a truthful wheel — not a longer format list.
- **Constraints:** solo developer, no 600 MB LibreOffice bundle, no paywall, no telemetry, keep the app sandboxed.

---

## Advisor A — First Principles Thinker

**The job.** A drag-wheel utility sells exactly one thing: the user commits before seeing the result. The gesture is a bet placed at pointer-down, so the product's real asset isn't format count — it's the wheel as a contract. Tangerine's 275 paths matter only because each wedge fires. DragConvert's wheel currently issues contracts it cannot honor. That isn't a feature gap; it's the product failing at its only job.

**Plan, in order.**

1. **Delete the lies before adding anything.** Every wedge with no engine goes this week: WebP/AVIF/SVG output, PDF→Office/EPUB/MD, documents, slides, sheets, audio, video, subtitles, archives. A 60-path wheel that always works beats 275 that sometimes fail. Hiding also removes the "broken or unsupported?" ambiguity, which destroys trust faster than absence.

2. **Make dishonesty structurally impossible.** Stop hand-maintaining the capability graph. Derive the wheel from an engine registry — a (input UTI, output UTI) → engine lookup — with a test asserting every offered edge resolves to a working encoder. This is the leverage: it makes all future breadth additive and safe instead of a new liability each time.

3. **Fix the three contract violations wrapped around it.** Sticky wheel, because release-modifier-as-cancel punishes the deliberation the wheel exists to buy. Copy must put URLs on the clipboard, because that is what the word means. Mixed selections must resolve to the intersection of valid tools, because real drags are plural.

4. **Then buy breadth cheaply.** WebP/AVIF/SVG encoders first, since they close claims already made and sit next to ImageIO. FFmpeg for video/audio only as optional install — never bundled — preserving the small binary and clean licence story.

**Where to win.** Don't out-format Tangerine; out-*trust* it. macOS 13 floor, offline by entitlement, MIT-auditable, no account, optional dependencies instead of a 500MB bundle, an instant native wheel against its reported M1 lag. Its self-admitted weakness is invisible-tool discoverability: be the legible, keyboard-navigable wheel where every wedge that appears is one that works.

---

## Advisor B — Expansionist / Strategist

**P0 is a lying problem, not a feature problem.** Ship a fail-closed release in a week: delete every unimplemented node from the capability graph, fix ⇧⌥, make Copy put URLs on the clipboard, keep the wheel sticky until drop/Escape, add thumbnail + size to the centre, and return a common-format wheel for mixed selections instead of `unknown`. That's ~5 items, no new engines. Every format added on top of a graph that lies is wasted work and a support burden. This release is the credibility floor, not a milestone.

**Then spend two weeks only where ImageIO already does the work:** WebP/AVIF/SVG *output*. Pure closure of the most visible image gap, zero new dependencies.

**The asymmetric bet: don't bundle LibreOffice and FFmpeg — abstract them.** Make the conversion graph declarative (manifest + `Provider` protocol) with optional shell-out providers for `ffmpeg`, `pandoc`, `soffice`, installed in-app. You inherit 200+ paths without maintaining 200+ paths, and because the repo is MIT, contributors add paths a closed $30 binary structurally cannot accept. This is the one move that turns breadth from a treadmill into an asset. OpenShelf validated the model; you can own it with a better wheel.

**Adjacent upside Tangerine has no answer for: headless operation.** URL scheme, Shortcuts actions, `dragconvert` CLI, watch folders. Same engine, an entirely new buyer — automation, CI, developer pipelines — where "GUI-only, $30, Apple silicon only" is disqualifying.

**Positioning: not "free Tangerine." Be the wheel that cannot lie to you.** No network entitlement is *auditable* in the signed bundle; theirs is a privacy-policy promise. Add macOS 13 + Intel, VoiceOver, reproducible builds. Their known M1 micro-lag and invisible-tool discoverability are your cheapest wins: latency and type-to-filter on the wheel.

Catch up on the five interaction bugs. Leapfrog on extensibility, headless, and provable privacy.

---

## Advisor C — Contrarian / Red Team

**The core risk isn't missing formats — it's that the app lies, and hiding the lie is not free.** Every wedge in the graph without an engine is a promise broken at the exact moment of highest intent: the user dragged a file and expected output. That user doesn't file a bug, they delete the app and tell one person. Hiding is the one change you can ship this week and it's the only true P0. Everything else in the dossier's P0 list is downstream of it.

**But hiding has a hidden cost nobody prices:** strip the graph to what works and you have a five-format image converter with nine PDF tools. That is not a Tangerine alternative, it's Preview with a radial menu. Free MIT doesn't rescue that — contributors evaluating the repo will see a capability graph with no engines and bounce, and "free" only reframes $0 as *worth $0* when the format list is shorter.

**Three hidden costs the dossier understates:**

1. **Fidelity, not coverage.** ImageIO round-trips silently drop color profiles, 16-bit depth, and alpha. A designer converting a CMYK TIFF and getting a washed-out sRGB JPEG is a worse review than "unsupported format." Working paths that produce wrong output are trust debt you can't hide.
2. **The sticky wheel is a rewrite, not a patch.** `DragMonitor` rebuilds the session on modifier change and `updateWheel` hides it. Keeping it alive until drop/Escape means moving wheel ownership out of the modifier lifecycle, and mixed selections returning `unknown` is baked into the kind graph. Budget days, not hours.
3. **Updates vs. no-network.** Sparkle needs the network entitlement that currently underwrites the "no telemetry, files local" story. Pick one and say it in the README.

**Don't build:** PDF→PPTX/XLSX (layout reconstruction you'll do badly), bundled LibreOffice (600 MB, sandbox-hostile, LGPL paperwork — OpenShelf already punted to optional installs, and that friction is exactly what $29.99 buys away).

**Do build:** FFmpeg for audio/video/animated GIF — ~40 paths plus 12 tools from one integration, the best paths-per-integration in the matrix — then WebP/AVIF encode.

**Where you win:** wheel fidelity with zero M1 lag, Intel + macOS 13, batch-everywhere, and a format matrix generated from the capability graph so the app structurally cannot lie again.

---

## Advisor D — Executor / Pragmatic Engineer

**Verdict: shrink the promise, then harden the promise.**

The cheapest high-leverage change in this entire dossier is deletion. Every advertised-but-unimplemented path — WebP/AVIF/SVG output, PDF→Office/EPUB, documents, slides, spreadsheets, audio, video, subtitles, archives — is a lie the wheel tells at the moment of peak trust. Removing those nodes from the capability graph is roughly a one-day change, adds zero dependency risk, and converts the single biggest credibility failure into a solved problem. Do it before writing any engine.

Then spend one week on the four fixes that buy more perceived parity than any new format: sticky wheel (stop calling `hide()` on modifier release; hold until drop/Escape), shortcut to ⇧⌥, Copy action → clipboard URLs, thumbnail + size in the wheel centre. All AppKit, all local, no sandbox impact. These are also Tangerine's most-praised behaviours.

**Do not chase 275 paths.** Each family is a permanent maintenance contract, not a feature. PDF→Office and the document/slide/spreadsheet families mean LibreOffice or Pandoc: hundreds of MB, licence and notarization work, sandbox friction, and an update treadmill a solo dev loses. FFmpeg is the same trap at smaller scale — LGPL build, two architectures, hardened runtime, then twelve tools needing QA. If you ever do media, copy OpenShelf's model: optional, user-installed, clearly labelled. Never bundle it.

Go deeper than Tangerine in the one vertical where the engine already exists: images and PDF. WebP encode via ImageIO is nearly free; AVIF/SVG need a real encoder or stay hidden. Add PDF/A-2b and annotation-preserving export — concrete, testable, and something Tangerine markets as a headline feature.

**Ship gate before any new engine:** app icon, menu-bar template icon, notarization, Sparkle updates. Without those this is a repository, not a product.

**Where you actually win:** MIT licensing, macOS 13 support, no telemetry, and a Finder-selection/Services path requiring no drag. Tangerine is Apple-silicon-only and $29.99 — that's a real constituency, not a consolation prize.

---

## Advisor E — Outsider / Domain Skeptic

The premise is slightly wrong, and that matters. The end-user problem isn't "convert 275 paths" — it's "I have a file, I need it in another form *now*, without opening an app or learning a format taxonomy." Tangerine sells that promise at $29.99. DragConvert currently breaks that promise on the first try, and a broken one-shot trust interaction is unrecoverable: the user doesn't file a bug, they delete the app.

So the highest-leverage plan is **make the promise honest before making it wider.** Advertising 275 paths is worthless if the wheel lies, because the wheel *is* the product. Formats are inventory; the interaction is the moat.

**P0 — do these before any new engine:**
1. **Strip the capability graph to what ships.** A wheel that only shows real options is a feature, not a retreat. Ship a visible "not yet" list, never a wedge that fails.
2. **Sticky wheel** (persists until drop/Escape). This is table stakes; its absence makes the app feel broken, not minimal.
3. **Copy → clipboard**, **⇧⌥ tools shortcut**, **GIF-as-video, PPTX-as-slides, RTFD input** — cheap bugs that contradict the app's own claims.
4. **Thumbnail + size + appear motion** in the centre. Costs a day; converts the wheel from a menu into a confirmation.

**Then build exactly one media path**, not nine: video → MP4/GIF + audio extraction via *optional* FFmpeg with a clear install prompt. That's the real second-most-wanted conversion and Tangerine's least-proven area.

**Then PDF text/Markdown via Vision OCR.** Native, zero dependencies, high pain, and it beats Tangerine on something users actually feel: searchable PDFs.

**Where DragConvert wins rather than catches up:** don't chase document/slide/spreadsheet fidelity — that's a LibreOffice bundling nightmare that turns a 20MB native app into a 600MB liability. Win on **automation**: Finder-selection-without-drag, Shortcuts/AppleScript/CLI, watch folders and recipes. A free MIT app can be scriptable in ways a $29.99 sandboxed MAS app won't be. Pair that with macOS 13 + Intel support, accessibility, and genuinely transparent development. That's a different product, not a worse Tangerine — and it's the only version of DragConvert that wins.

---

## Peer review 1

**1. Strongest argument — C.** It's the only advisor to price the cost of its own advice: strip the graph and you ship "Preview with a radial menu," so deletion alone doesn't create a competitor. It also contributes the one non-obvious technical finding — ImageIO round-trips dropping color profiles, 16-bit depth and alpha — proving a *working* path can still betray trust. Plus it catches the Sparkle-vs-no-network-entitlement contradiction and reads the sticky wheel as a lifecycle ownership change, not a one-line fix.

**2. Fatal blind spot — D.** "Stop calling `hide()` on modifier release" directly contradicts the dossier's code facts: `DragMonitor` rebuilds the session and `updateWheel` hides the wheel. Its "one week, all AppKit, no sandbox impact" estimate is therefore unsupported. Its "WebP encode via ImageIO is nearly free" (shared with B) is an unverified platform assumption — ImageIO decodes WebP; it does not reliably encode it.

**3. Missing consideration — demand evidence.** All five roadmap off Tangerine's feature matrix, never off what DragConvert users actually drag. With no telemetry by design, nobody proposes an opt-in signal, a success metric, or a kill criterion for any of these bets.

---

## Peer review 2

**1. Strongest argument — C.** Alone in arguing from mechanisms, not vibes: ImageIO silently drops colour profiles, 16-bit depth and alpha, so *working* paths still produce wrong output — a worse review than "unsupported." C also correctly reads the code (`DragMonitor` rebuilding sessions, `updateWheel` hiding) and concludes the sticky wheel is a lifecycle rewrite, not a patch, and spots that Sparkle collides with the no-network entitlement. Every claim is checkable and changes sequencing; A, B, D and E mostly restate "the wheel lies."

**2. Fatal blind spot — D.** It budgets "one week" for four fixes including the sticky wheel C prices in days-to-weeks, and mandates Sparkle before any engine while claiming "no network entitlement" as the provable-privacy moat. You cannot ship both without saying which wins. A compounds this by calling optional FFmpeg a "clean licence story," ignoring LGPL relinking, hardened runtime, and sandboxed execution of user-installed binaries.

**3. Missing consideration — security and upkeep.** None examines parsing untrusted files locally (ImageIO/PDFKit/FFmpeg/LibreOffice are the actual attack surface; "no network" is not "safe"), nor who maintains hundreds of paths once the solo MIT author burns out. Breadth is a security and sustainability liability, not merely a QA one.

---

## Chairman synthesis

### Where the council agrees

1. **Truth is the P0.** Remove every wedge with no engine before adding any engine. A working 60-path wheel beats a failing 275-path wheel.
2. **The core interaction fixes are the cheapest perceived parity.** Sticky wheel, ⇧⌥, Copy-to-clipboard, mixed selections, thumbnail/size, file-kind fixes. These matter more than another format family.
3. **Do not chase 275 paths.** Each family is a permanent contract. Bundled LibreOffice is a trap; Office/slide/spreadsheet fidelity will be poor and expensive.
4. **Make the wheel engine-derived.** A capability graph with a test for every offered edge makes future breadth additive and safe.
5. **Build breadth where it compounds.** WebP/AVIF/SVG; optional FFmpeg for audio/video; native PDF OCR/PDF-A.
6. **Packaging is a gate.** Icon, menu-bar template, notarization, update policy, privacy/licences. A repository is not a product.

### Where the council clashes

- **How much breadth is enough?** The contrarian warns that a truthful but tiny app becomes "Preview with a radial menu." The expansionist argues for optional providers to inherit breadth. Resolution: ship the truthful core, then one compounding media path (optional FFmpeg) and one native PDF path (OCR/PDF-A) before considering Office.
- **FFmpeg: optional or bundled?** The contrarian calls it the best paths-per-integration; the executor says optional, user-installed only. Resolution: optional, clearly labelled, with a one-click installer and a licence screen. Never bundle 600 MB of LibreOffice.
- **Sparkle vs no-network.** Sparkle needs network access and weakens the "no network entitlement" claim. Resolution: choose App Store updates, or an explicit opt-in updater with updated privacy copy. Do not quietly add networking.

### Blind spots caught in peer review

- **Fidelity:** working conversions can still silently change colour profiles, bit depth, and alpha. Add fixtures before claiming parity.
- **Security:** local parsers are an attack surface. Sandbox/process isolation matters; "no network" is not "safe."
- **Maintenance and demand:** no success metric or kill criterion. Do not build 275 paths on faith; use a manual QA scorecard and opt-in local metrics.
- **Sticky wheel lifecycle:** it is a state-ownership change, not a one-line delete of `hide()`.

### Recommendation

**Ship a "Truthful Wheel" release first (about one week):**

1. Filter the capability graph to engines that exist; every offered wedge works.
2. Make the wheel sticky until drop/Escape.
3. Default to ⇧⌥; update onboarding/settings.
4. Copy puts URLs on the clipboard; add a terminal-app picker.
5. Support mixed compatible selections; fix GIF/PPTX/RTFD.
6. Draw the dragged-file thumbnail and size in the centre; add appear motion.
7. Add app icon, menu-bar template icon, and a visible "not yet" path.

**Then 2–3 weeks of compounding work:** WebP/AVIF/SVG; PDF OCR → TXT/MD/DOCX/Pages, PDF/A-2b, annotation-preserving compression/export; metadata editor; photo/annotate/redact depth.

**Then optional media:** user-installed FFmpeg provider with licence screen; audio/video conversions and the 12 media tools. Optional Pandoc/LibreOffice only if demand justifies it.

**In parallel:** notarization, update channel, privacy/licences, accessibility, Intel build, and a Finder-selection/Shortcuts path.

### Immediate next step

**TRUTH-1:** replace the hand-maintained capability graph with an engine-derived one, and add a test that every offered wedge resolves to a working encoder. Then **WHEEL-5** (sticky), **WHEEL-6** (centre preview/motion), **ACT-5** (Copy/terminal), **DRAG-3** (mixed selections/kinds), and **PKG-0** (product gate).
