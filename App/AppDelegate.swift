import AppKit
import PDFKit
import SwiftUI
import DragSense
import CapabilityGraph
import WheelUI
import JobCore
import EngineKit
import PDFEngine
import ImageEngine
import DocumentEngine
import MediaEngine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let monitor = DragMonitor()
    private let wheel = WheelController()
    private var onboardingWindow: OnboardingWindowController?
    private var settingsWindow: SettingsWindowController?
    private var lastOutputs: [URL] = []
    private var showMenuBarIcon = true

    private var lastSession: FileDragSession?
    private var lastSignature: String?
    private var lastHoveredID: String?
    /// The last wheel selected during this drag. Tangerine keeps the wheel
    /// alive after the modifier is released, so this outlives the modifier
    /// flags. It resets when the drag ends.
    private var modeTracker = WheelModeTracker()
    private var wheelDismissed = false
    private var lastUnsupportedKey: String?
    private var currentPreview: WheelPreview?
    private var currentPreviewKey: String?
    /// The polled-pointer fallback and `performDragOperation` can both fire for
    /// the same release. Deduplicate so we never convert twice.
    private var lastPerform: (key: String, date: Date)?

    private let hud = HUDController()
    private var batchTask: Task<Void, Never>?
    private var engineTask: Task<[URL], Error>?
    private var cropWindow: CropWindowController?
    private var cropPDFWindow: CropPDFWindowController?
    private var cropTask: Task<Void, Never>?
    private var adjustWindow: ImageAdjustWindowController?
    private var adjustTask: Task<Void, Never>?
    private var compressWindow: CompressWindowController?
    private var compressTask: Task<Void, Never>?
    private var compressPDFWindow: CompressPDFWindowController?
    private var frameWindow: FrameImageWindowController?
    private var framePDFWindow: FramePDFWindowController?
    private var frameTask: Task<Void, Never>?
    private var collageWindow: CollageImageWindowController?
    private var photoEditorWindow: PhotoEditorWindowController?
    private var qrWindow: QRResultWindowController?
    private var qrTask: Task<Void, Never>?
    private var moreToolsWindow: MoreToolsWindowController?
    private var moreFormatsWindow: MoreFormatsWindowController?
    private var extractTask: Task<Void, Never>?
    private var pdfaTask: Task<Void, Never>?
    private var metadataWindow: MetadataWindowController?
    private var metadataTask: Task<Void, Never>?
    private var splitWindow: SplitPDFWindowController?
    private var organizeWindow: OrganizePDFWindowController?
    private var annotateWindow: AnnotatePDFWindowController?
    private var annotateImageWindow: AnnotateImageWindowController?
    private var redactWindow: RedactPDFWindowController?
    private var redactImageWindow: RedactImageWindowController?
    private var pdfTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.write("launched")
        UserDefaults.standard.register(defaults: [
            "revealOnFinish": true,
            "soundEnabled": true,
            "hapticsEnabled": true
        ])
        WheelShortcuts.migrateLegacyDefaults()
        UpdateChecker.shared.start()

        // Re-activate the home-folder security-scoped bookmark at launch.
        // Dragging a file grants read access to that file, but writing the
        // result beside it needs the folder bookmark. Without this, every
        // conversion reads the input and then fails to create its temp file.
        _ = FolderAccess.shared.ensureAccess(promptIfNeeded: false)
        setUpStatusItem()

        showMenuBarIcon = UserDefaults.standard.object(forKey: "showMenuBarIcon") as? Bool ?? true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuBarVisibilityChanged(_:)),
            name: .menuBarVisibilityChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showOnboardingFromSettings),
            name: .showOnboarding,
            object: nil
        )
        applyMenuBarVisibility(showMenuBarIcon, showSettingsIfHidden: true)

        wheel.onDrop = { [weak self] item, urls in
            Log.write("drop via draggingDestination \(item.id)")
            self?.perform(item: item, on: urls)
        }

        wheel.onActivate = { [weak self] item in
            guard let self, let files = self.lastSession?.files, !files.isEmpty else { return }
            Log.write("keyboard activate \(item.id)")
            self.perform(item: item, on: files)
        }

        wheel.onCancel = { [weak self] in
            Log.write("wheel dismissed with Escape")
            self?.wheelDismissed = true
        }

        wheel.onOpenSettings = { [weak self] in
            Log.write("settings opened from wheel comma")
            self?.showSettings()
        }

        monitor.onChange = { [weak self] session in
            self?.updateWheel(for: session)
        }
        monitor.start()

        if CommandLine.arguments.contains("--hud-demo") {
            hud.show(title: "Converting to JPG", subtitle: "2 of 4 pages")
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.hud.succeed(title: "Converted to JPG", subtitle: "1 of 1 saved")
            }
        }

        if CommandLine.arguments.contains("--hud-error-demo") {
            hud.show(title: "Converting to JPG", subtitle: "2 of 4 pages")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                self.hud.fail("No permission to save there. Use “Grant Folder Access…” and try again.")
            }
        }

        if let index = CommandLine.arguments.firstIndex(of: "--crop-demo"),
           CommandLine.arguments.count > index + 1 {
            let path = CommandLine.arguments[index + 1]
            presentCrop(for: [URL(fileURLWithPath: path)])
        }

        if let index = CommandLine.arguments.firstIndex(of: "--adjust-demo"),
           CommandLine.arguments.count > index + 1 {
            let path = CommandLine.arguments[index + 1]
            presentAdjust(for: [URL(fileURLWithPath: path)], mode: .resize)
        }

        if let index = CommandLine.arguments.firstIndex(of: "--compress-demo"),
           CommandLine.arguments.count > index + 1 {
            let path = CommandLine.arguments[index + 1]
            presentCompress(for: [URL(fileURLWithPath: path)])
        }

        if let index = CommandLine.arguments.firstIndex(of: "--metadata-demo"),
           CommandLine.arguments.count > index + 1 {
            let path = CommandLine.arguments[index + 1]
            presentMetadata(for: [URL(fileURLWithPath: path)])
        }

        if let index = CommandLine.arguments.firstIndex(of: "--split-demo"),
           CommandLine.arguments.count > index + 1 {
            let path = CommandLine.arguments[index + 1]
            presentSplit(for: [URL(fileURLWithPath: path)])
        }

        if let index = CommandLine.arguments.firstIndex(of: "--organize-demo"),
           CommandLine.arguments.count > index + 1 {
            let path = CommandLine.arguments[index + 1]
            presentOrganize(for: [URL(fileURLWithPath: path)])
        }

        if let index = CommandLine.arguments.firstIndex(of: "--pdfcompress-demo"),
           CommandLine.arguments.count > index + 1 {
            let path = CommandLine.arguments[index + 1]
            presentCompress(for: [URL(fileURLWithPath: path)])
        }

        if let index = CommandLine.arguments.firstIndex(of: "--pdfcrop-demo"),
           CommandLine.arguments.count > index + 1 {
            let path = CommandLine.arguments[index + 1]
            presentCrop(for: [URL(fileURLWithPath: path)])
        }

        if let index = CommandLine.arguments.firstIndex(of: "--moretools-demo"),
           CommandLine.arguments.count > index + 1 {
            let path = CommandLine.arguments[index + 1]
            presentMoreTools(for: [URL(fileURLWithPath: path)])
        }

        if let index = CommandLine.arguments.firstIndex(of: "--moreformats-demo"),
           CommandLine.arguments.count > index + 1 {
            let path = CommandLine.arguments[index + 1]
            presentMoreFormats(for: [URL(fileURLWithPath: path)])
        }

        if let index = CommandLine.arguments.firstIndex(of: "--extract-demo"),
           CommandLine.arguments.count > index + 1 {
            let path = CommandLine.arguments[index + 1]
            runExtractArchives([URL(fileURLWithPath: path)])
        }

        if let index = CommandLine.arguments.firstIndex(of: "--annotate-demo"),
           CommandLine.arguments.count > index + 1 {
            let path = CommandLine.arguments[index + 1]
            presentAnnotate(for: [URL(fileURLWithPath: path)])
        }

        if let index = CommandLine.arguments.firstIndex(of: "--redact-demo"),
           CommandLine.arguments.count > index + 1 {
            let path = CommandLine.arguments[index + 1]
            presentRedact(for: [URL(fileURLWithPath: path)])
        }

        if let index = CommandLine.arguments.firstIndex(of: "--edit-demo"),
           CommandLine.arguments.count > index + 1 {
            presentPhotoEditor(for: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
        }

        if let index = CommandLine.arguments.firstIndex(of: "--pdfframe-demo"),
           CommandLine.arguments.count > index + 1 {
            presentFrame(for: [URL(fileURLWithPath: CommandLine.arguments[index + 1])])
        }

        if let index = CommandLine.arguments.firstIndex(of: "--qr-demo"),
           CommandLine.arguments.count > index + 1 {
            runReadQR(input: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
        }

        if let index = CommandLine.arguments.firstIndex(of: "--removebg-demo"),
           CommandLine.arguments.count > index + 1 {
            runRemoveBG(input: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
        }

        if let index = CommandLine.arguments.firstIndex(of: "--collage-demo") {
            let paths = CommandLine.arguments[(index + 1)...]
                .filter { !$0.hasPrefix("--") }
                .map { URL(fileURLWithPath: $0) }
            presentCollage(for: Array(paths))
        }

        if let index = CommandLine.arguments.firstIndex(of: "--crop-batch-demo"),
           CommandLine.arguments.count > index + 2 {
            let first = URL(fileURLWithPath: CommandLine.arguments[index + 1])
            let second = URL(fileURLWithPath: CommandLine.arguments[index + 2])
            presentCrop(for: [first, second])
        }

        if let index = CommandLine.arguments.firstIndex(of: "--annotate-image-demo"),
           CommandLine.arguments.count > index + 1 {
            let path = CommandLine.arguments[index + 1]
            presentAnnotate(for: [URL(fileURLWithPath: path)])
        }

        if let index = CommandLine.arguments.firstIndex(of: "--redact-image-demo"),
           CommandLine.arguments.count > index + 1 {
            let path = CommandLine.arguments[index + 1]
            Log.write("redact image demo start \(path)")
            presentRedact(for: [URL(fileURLWithPath: path)])
        }

        if let index = CommandLine.arguments.firstIndex(of: "--frame-demo"),
           CommandLine.arguments.count > index + 1 {
            let path = CommandLine.arguments[index + 1]
            presentFrame(for: [URL(fileURLWithPath: path)])
        }

        if let styleIndex = CommandLine.arguments.firstIndex(of: "--wheel-style"),
           styleIndex + 1 < CommandLine.arguments.count {
            UserDefaults.standard.set(
                CommandLine.arguments[styleIndex + 1],
                forKey: "wheelStyle"
            )
        }

        if let demoIndex = CommandLine.arguments.firstIndex(of: "--wheel-demo") {
            let path = demoIndex + 1 < CommandLine.arguments.count
                && !CommandLine.arguments[demoIndex + 1].hasPrefix("--")
                ? CommandLine.arguments[demoIndex + 1]
                : ""
            let files = path.isEmpty ? [] : [URL(fileURLWithPath: path)]
            let mode: WheelMode = CommandLine.arguments.contains("--wheel-tools")
                ? .tools
                : (CommandLine.arguments.contains("--wheel-actions") ? .actions : .convert)
            let items = files.isEmpty
                ? Capabilities.items(mode: .actions, kind: .pdf)
                : validItems(mode: mode, files: files)
            let preview = files.isEmpty
                ? WheelPreview(
                    image: NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/Finder.app"),
                    fileName: "Actions",
                    fileSize: "6 actions",
                    isMultiple: false
                )
                : wheelPreview(for: files)
            if !items.isEmpty {
                wheel.show(items: items, at: NSEvent.mouseLocation, preview: preview)
                if let hoverIndex = CommandLine.arguments.firstIndex(of: "--wheel-hover"),
                   hoverIndex + 1 < CommandLine.arguments.count,
                   let index = Int(CommandLine.arguments[hoverIndex + 1]) {
                    wheel.highlight(index)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                Log.write("wheel demo key=\(self.wheel.isKeyWindow) visible=\(self.wheel.visible) appActive=\(NSApp.isActive) front=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil")")
            }
        }

        if let demoIndex = CommandLine.arguments.firstIndex(of: "--convert-demo"),
           demoIndex + 2 < CommandLine.arguments.count {
            let path = CommandLine.arguments[demoIndex + 1]
            let target = CommandLine.arguments[demoIndex + 2]
            perform(
                item: WheelItem(
                    id: "convert:\(target)",
                    title: target.uppercased(),
                    symbol: ""
                ),
                on: [URL(fileURLWithPath: path)]
            )
        }

        if let index = CommandLine.arguments.firstIndex(of: "--pdfa-demo"),
           index + 1 < CommandLine.arguments.count {
            runPDFA(input: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
        }

        if CommandLine.arguments.contains("--settings-demo") {
            showSettings()
        }

        if CommandLine.arguments.contains("--about-demo") {
            showAbout()
        }

        if let index = CommandLine.arguments.firstIndex(of: "--shelf-demo") {
            let paths = CommandLine.arguments[(index + 1)...]
                .filter { !$0.hasPrefix("--") }
                .map { URL(fileURLWithPath: $0) }
            ShelfController.shared.add(Array(paths))
        }

        if let index = CommandLine.arguments.firstIndex(of: "--onboarding-demo") {
            let page = index + 1 < CommandLine.arguments.count
                ? (Int(CommandLine.arguments[index + 1]) ?? 0)
                : 0
            showOnboarding(page: page)
        }

        DestinationPolicy.policy = ConflictPolicy(
            rawValue: UserDefaults.standard.string(forKey: "conflictPolicy") ?? ""
        ) ?? .rename

        if !UserDefaults.standard.bool(forKey: "hasSeenWelcome") {
            showWelcome()
            UserDefaults.standard.set(true, forKey: "hasSeenWelcome")
        }
    }

    // MARK: Menu bar

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: 24)
        StatusIcon.apply(to: item.button)
        Log.write("status item visible=\(item.isVisible) button=\(item.button != nil)")
        item.button?.toolTip = "Drag a file, then hold ⇧ to convert, ⌘ for tools, ⌃ for actions"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "About DragConvert", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "How it works…", action: #selector(showWelcome), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Grant Folder Access…", action: #selector(grantFolderAccess), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Reveal Last Result", action: #selector(revealLast), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Shelf", action: #selector(toggleShelf), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit DragConvert", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    // MARK: Wheel

    private func updateWheel(for session: FileDragSession?) {
        guard let session else {
            finishDrag()
            return
        }
        if wheel.isLocked { return }
        if wheelDismissed { return }
        lastSession = session

        // Tap once to open. Releasing the key must not close the wheel; that
        // is the Tangerine/OpenShelf behaviour and the whole point of the
        // deliberate radial selection.
        guard let mode = modeTracker.update(modifiers: session.modifiers) else {
            wheel.hide()
            return
        }

        let kinds = session.files.map(FileKind.detect)
        let items = validItems(mode: mode, files: session.files)
        if items.isEmpty {
            wheel.hide()
            if lastUnsupportedKey != session.signature {
                lastUnsupportedKey = session.signature
                hud.note(
                    title: "Nothing here yet",
                    subtitle: unsupportedMessage(mode: mode, kinds: kinds)
                )
            }
            return
        }

        let preview = wheelPreview(for: session.files)
        if lastSignature != session.signature {
            lastSignature = session.signature
            let kindList = kinds.map(\.rawValue).joined(separator: ",")
            Log.write("drag \(session.files.count) file(s) mode=\(mode.rawValue) kinds=\(kindList) items=\(items.count)")
        }

        wheel.show(items: items, at: session.point, preview: preview)
        wheel.updateHover(atScreenPoint: session.point)

        let hovered = wheel.hoveredItem?.id
        if hovered != lastHoveredID {
            lastHoveredID = hovered
            Log.write("hover \(hovered ?? "none")")
        }
    }

    /// Only show wedges that have a real engine behind them. This is the
    /// truth gate: no failing conversions, no phantom video/audio tools.
    private func validItems(mode: WheelMode, files: [URL]) -> [WheelItem] {
        switch mode {
        case .actions:
            return Capabilities.actions

        case .convert:
            let targets = supportedConversionTargets(for: files)
            let visible = targets.count > 7
                ? Array(targets.prefix(6))
                : targets
            var items = visible.map { target in
                WheelItem(
                    id: "convert:\(target)",
                    title: target.uppercased(),
                    symbol: ""
                )
            }
            if targets.count > 7 {
                items.append(
                    WheelItem(id: "convert:more", title: "MORE", symbol: "ellipsis.circle")
                )
            }
            return items

        case .tools:
            let kinds = Array(Set(files.map(FileKind.detect)))
            guard kinds.count == 1,
                  let kind = kinds.first,
                  [.image, .pdf, .archive].contains(kind) else { return [] }
            return Capabilities.tools(kind, fileCount: files.count).filter {
                supportedTool($0, kind: kind, files: files)
            }
        }
    }

    private func supportedConversionTargets(for files: [URL]) -> [String] {
        let kinds = files.map(FileKind.detect)
        guard !kinds.contains(.unknown), !kinds.isEmpty else { return [] }
        return Capabilities.convertTargetList(
            kinds: kinds,
            inputExtensions: files.map(\.pathExtension)
        ).filter { target in
            files.allSatisfy { file in
                guard let engine = engine(for: file, target: target) else { return false }
                return engine.canHandle(
                    Job(inputs: [file], operation: .convert(to: target))
                )
            }
        }
    }

    private func supportedTool(_ item: WheelItem, kind: FileKind, files: [URL]) -> Bool {
        let imageTools: Set<String> = [
            "tool:compress", "tool:crop", "tool:resize", "tool:rotate",
            "tool:annotate", "tool:addbg", "tool:redact", "tool:removebg",
            "tool:metadata", "tool:collage", "tool:readqr", "tool:edit",
            "tool:more"
        ]
        let pdfTools: Set<String> = [
            "tool:compress", "tool:metadata", "tool:split",
            "tool:organize", "tool:pdfa", "tool:readqr", "tool:merge",
            "tool:annotate", "tool:redact", "tool:addbg", "tool:crop",
            "tool:more"
        ]
        let archiveTools: Set<String> = ["tool:extract"]

        switch kind {
        case .image:
            guard imageTools.contains(item.id) else { return false }
            if files.count > 1 {
                return item.id == "tool:crop" || item.id == "tool:collage"
            }
            return true
        case .pdf:
            guard pdfTools.contains(item.id) else { return false }
            if files.count > 1 { return item.id == "tool:merge" }
            return true
        case .archive:
            return archiveTools.contains(item.id)
        default:
            return false
        }
    }

    private func unsupportedMessage(mode: WheelMode, kinds: [FileKind]) -> String {
        if kinds.contains(.video) {
            return mode == .tools
                ? "Video editing tools aren’t built yet. Hold ⇧ for video conversions."
                : "This video container isn’t readable by macOS. Try MP4, MOV or M4V."
        }
        if kinds.contains(.slides) {
            return "Presentation conversion is the next family."
        }
        if kinds.contains(.audio) {
            return mode == .tools
                ? "Audio tools aren’t built yet. Hold ⇧ for audio conversions."
                : "This audio format isn’t readable by macOS. Try MP3, M4A, WAV, FLAC or AIFF."
        }
        if kinds.contains(.document) || kinds.contains(.spreadsheet) {
            return "Hold ⇧ for document and spreadsheet conversions."
        }
        if kinds.contains(.archive) {
            return "RAR and 7-Zip are extract-only. Hold ⌥⌘ for the tools wheel."
        }
        return "No \(mode.rawValue) wedges for this file yet."
    }

    private func wheelPreview(for files: [URL]) -> WheelPreview {
        let key = files.map(\.path).joined(separator: "|")
        if currentPreviewKey == key, let currentPreview { return currentPreview }

        let label = files.count == 1
            ? files[0].lastPathComponent
            : "\(files.count) files"
        let image: NSImage?
        if let first = files.first {
            switch FileKind.detect(first) {
            case .image:
                if let cg = ImageConvertEngine.loadPreview(at: first, maxPixel: 160) {
                    image = NSImage(
                        cgImage: cg,
                        size: NSSize(width: cg.width, height: cg.height)
                    )
                } else {
                    image = NSWorkspace.shared.icon(forFile: first.path)
                }
            case .pdf:
                image = PDFDocument(url: first)?
                    .page(at: 0)?
                    .thumbnail(of: NSSize(width: 160, height: 160), for: .cropBox)
            default:
                image = NSWorkspace.shared.icon(forFile: first.path)
            }
        } else {
            image = nil
        }

        let total = files.reduce(Int64(0)) { partial, url in
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
            return partial + size
        }
        let sizeText: String
        if files.count > 1 {
            sizeText = "\(files.count) items · \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))"
        } else if total > 0 {
            sizeText = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
        } else {
            sizeText = "Folder"
        }

        let preview = WheelPreview(
            image: image,
            fileName: label,
            fileSize: sizeText,
            isMultiple: files.count > 1
        )
        currentPreview = preview
        currentPreviewKey = key
        return preview
    }

    private func finishDrag() {
        defer { resetDragState() }
        Log.write("drag ended, visible=\(wheel.visible) hovered=\(wheel.hoveredItem?.id ?? "none") locked=\(wheel.isLocked)")
        if wheel.isLocked {
            // A keyboard choice already ran; keep the panel up only long
            // enough to absorb Finder's drop, then close.
            wheel.hide()
            return
        }

        // If the panel never received `performDragOperation` (it appeared
        // mid-drag, which can confuse the drag destination), finish the job
        // ourselves from the last polled session.
        if let item = wheel.hoveredItem, let files = lastSession?.files, !files.isEmpty {
            Log.write("drop via polled pointer \(item.id)")
            perform(item: item, on: files)
        }

        wheel.hide()
    }

    private func resetDragState() {
        lastSession = nil
        lastSignature = nil
        lastHoveredID = nil
        modeTracker.reset()
        wheelDismissed = false
        lastUnsupportedKey = nil
        currentPreview = nil
        currentPreviewKey = nil
    }

    // MARK: Jobs

    private func perform(item: WheelItem, on urls: [URL]) {
        lastSession = nil
        guard !urls.isEmpty else { return }

        let key = item.id + "|" + urls.map(\.path).joined(separator: "|")
        if let last = lastPerform, last.key == key, Date().timeIntervalSince(last.date) < 1.0 {
            Log.write("ignored duplicate drop \(item.id)")
            return
        }
        lastPerform = (key, Date())

        Log.write("perform \(item.id) on \(urls.count) file(s)")

        // Conversions and editors write beside the original. Make sure the
        // bookmark is active before any engine tries to create a temp file.
        // Read QR is the one non-action that never writes.
        if item.id != "tool:readqr" {
            guard FolderAccess.shared.ensureAccess() else {
                hud.fail("Grant Folder Access… so results can be saved beside the original.")
                return
            }
        }

        if item.id.hasPrefix("action:") {
            performAction(item, on: urls)
            return
        }

        if item.id == "tool:more" {
            presentMoreTools(for: urls)
            return
        }

        if item.id == "tool:extract" {
            runExtractArchives(urls)
            return
        }

        if item.id == "tool:crop" {
            presentCrop(for: urls)
            return
        }

        if item.id == "tool:resize" || item.id == "tool:rotate" {
            presentAdjust(
                for: urls,
                mode: item.id == "tool:resize" ? .resize : .rotate
            )
            return
        }

        if item.id == "tool:compress" {
            presentCompress(for: urls)
            return
        }

        if item.id == "tool:metadata" {
            presentMetadata(for: urls)
            return
        }

        if item.id == "tool:addbg" {
            presentFrame(for: urls)
            return
        }

        if item.id == "tool:collage" {
            presentCollage(for: urls)
            return
        }

        if item.id == "tool:edit" {
            guard let input = urls.first, FileKind.detect(input) == .image else {
                hud.fail("Edit is wired for images so far")
                return
            }
            presentPhotoEditor(for: input)
            return
        }

        if item.id == "tool:readqr" {
            guard let input = urls.first,
                  [.image, .pdf].contains(FileKind.detect(input)) else {
                hud.fail("Read QR needs an image or PDF")
                return
            }
            runReadQR(input: input)
            return
        }

        if item.id == "tool:pdfa" {
            guard let input = urls.first, FileKind.detect(input) == .pdf else {
                hud.fail("PDF/A-2B needs a PDF")
                return
            }
            runPDFA(input: input)
            return
        }

        if item.id == "tool:removebg" {
            guard let input = urls.first, FileKind.detect(input) == .image else {
                hud.fail("Remove BG is wired for images so far")
                return
            }
            runRemoveBG(input: input)
            return
        }

        if item.id == "tool:merge" {
            runMerge(urls)
            return
        }

        if item.id == "tool:split" {
            presentSplit(for: urls)
            return
        }

        if item.id == "tool:organize" {
            presentOrganize(for: urls)
            return
        }

        if item.id == "tool:annotate" {
            presentAnnotate(for: urls)
            return
        }

        if item.id == "tool:redact" {
            presentRedact(for: urls)
            return
        }

        if item.id == "convert:more" {
            presentMoreFormats(for: urls)
            return
        }

        guard item.id.hasPrefix("convert:") else {
            Log.write("not implemented: \(item.id)")
            hud.fail("\(item.title) isn’t built yet")
            return
        }

        let target = String(item.id.dropFirst("convert:".count))
        let files = urls.filter {
            normalisedExtension($0.pathExtension) != normalisedExtension(target)
        }
        guard !files.isEmpty else {
            hud.note(
                title: "Already \(target.uppercased())",
                subtitle: "Every selected file is already in that format."
            )
            return
        }

        // Multiple images onto PDF means "build one PDF", not "one PDF each".
        if target.lowercased() == "pdf",
           files.count > 1,
           files.allSatisfy({ FileKind.detect($0) == .image }) {
            runImagesToPDF(files)
            return
        }

        batchTask?.cancel()
        engineTask?.cancel()

        hud.onCancel = { [weak self] in
            Log.write("cancel requested")
            self?.engineTask?.cancel()
            self?.batchTask?.cancel()
        }
        hud.show(
            title: "Converting to \(target.uppercased())",
            subtitle: files.count == 1 ? "Preparing…" : "1 of \(files.count)"
        )
        StatusIcon.setBusy(true, on: statusItem?.button)

        batchTask = Task { @MainActor [self] in
            await runConversionBatch(files: files, target: target)
        }
    }

    @MainActor
    private func runConversionBatch(files: [URL], target: String) async {
        Log.write("batch task started target=\(target)")
        var outputs: [URL] = []

        for (index, input) in files.enumerated() {
            if Task.isCancelled { break }

            let job = Job(inputs: [input], operation: .convert(to: target))
            guard let engine = engine(for: input, target: target), engine.canHandle(job) else {
                hud.fail("Can’t convert \(input.lastPathComponent) to \(target.uppercased())")
                StatusIcon.setBusy(false, on: statusItem?.button)
                return
            }

            if files.count > 1 {
                hud.update(subtitle: "\(index + 1) of \(files.count)")
            }

            Log.write("job start \(input.path) → \(target)")
            let task = Task.detached(priority: .userInitiated) {
                try await engine.run(job) { _ in }
            }
            engineTask = task

            do {
                let result = try await task.value
                outputs.append(contentsOf: result)
                hud.update(
                    subtitle: files.count == 1
                        ? "Saving…"
                        : "\(index + 1) of \(files.count) saved"
                )
            } catch is CancellationError {
                hud.hide()
                StatusIcon.setBusy(false, on: statusItem?.button)
                Log.write("cancelled")
                return
            } catch {
                hud.fail(error.friendlyMessage)
                StatusIcon.setBusy(false, on: statusItem?.button)
                Log.write("job failed \(input.path): \(error.localizedDescription)")
                return
            }
        }

        if Task.isCancelled {
            hud.hide()
            StatusIcon.setBusy(false, on: statusItem?.button)
            return
        }

        finished(outputs)
        StatusIcon.setBusy(false, on: statusItem?.button)
        hud.succeed(
            title: "Converted to \(target.uppercased())",
            subtitle: "\(files.count) of \(files.count) saved"
        )
        Log.write("batch done \(outputs.map(\.path))")
    }

    // MARK: File actions

    private func performAction(_ item: WheelItem, on urls: [URL]) {
        switch item.id {
        case "action:airdrop":
            guard let service = NSSharingService(named: .sendViaAirDrop) else {
                hud.fail("AirDrop isn’t available")
                return
            }
            service.perform(withItems: urls)
            Log.write("airdrop \(urls.count) items")

        case "action:float":
            ShelfController.shared.add(urls)
            hud.succeed(
                title: "Added to shelf",
                subtitle: urls.count == 1 ? urls[0].lastPathComponent : "\(urls.count) items"
            )

        case "action:copy":
            copyToPasteboard(urls)

        case "action:move":
            chooseDestination(for: urls)

        case "action:copypath":
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(
                urls.map(\.path).joined(separator: "\n"),
                forType: .string
            )
            hud.succeed(
                title: "Path copied",
                subtitle: urls.count == 1 ? urls[0].lastPathComponent : "\(urls.count) paths"
            )

        case "action:terminal":
            openTerminal(for: urls)

        default:
            hud.fail("\(item.title) isn’t built yet")
        }
    }

    private func copyToPasteboard(_ urls: [URL]) {
        FileActions.copyToPasteboard(urls)
        hud.succeed(
            title: "Copied",
            subtitle: urls.count == 1 ? urls[0].lastPathComponent : "\(urls.count) files on the clipboard"
        )
        Log.write("copied \(urls.count) file(s) to clipboard")
    }

    private func chooseDestination(for urls: [URL]) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Move Here"
        panel.message = "Choose a folder to move the selection into."

        guard panel.runModal() == .OK, let destination = panel.url else { return }

        let count = urls.count
        hud.onCancel = { [weak self] in self?.cropTask?.cancel() }
        hud.show(title: "Moving", subtitle: "\(count) items")

        cropTask = Task { @MainActor [weak self] in
            do {
                let outputs = try await Task.detached(priority: .userInitiated) {
                    try FileActions.transfer(urls, to: destination, moving: true)
                }.value
                self?.hud.succeed(
                    title: "Moved",
                    subtitle: outputs.isEmpty ? "Already in that folder" : "\(outputs.count) items"
                )
                Log.write("move done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                Log.write("move failed: \(error.localizedDescription)")
            }
        }
    }

    private func openTerminal(for urls: [URL]) {
        guard let first = urls.first else { return }
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(
            atPath: first.path, isDirectory: &isDirectory
        )
        let folder = (exists && isDirectory.boolValue)
            ? first
            : first.deletingLastPathComponent()

        guard let terminal = TerminalApps.selectedURL else {
            NSWorkspace.shared.open(folder)
            return
        }
        NSWorkspace.shared.open(
            [folder],
            withApplicationAt: terminal,
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, error in
            if let error { Log.write("terminal: \(error.localizedDescription)") }
        }
        Log.write("terminal at \(folder.path) via \(TerminalApps.selectedBundleID)")
    }

    @objc private func toggleShelf() {
        ShelfController.shared.toggle()
    }

    private func finished(_ outputs: [URL]) {
        lastOutputs = outputs
        Reveal.ifEnabled(outputs)
    }

    @objc private func showAbout() {
        presentSettings(tab: .about)
    }

    @objc private func checkForUpdates() {
        presentSettings(tab: .about)
        UpdateChecker.shared.check()
    }

    @objc private func showSettings() {
        presentSettings(tab: .general)
    }

    private func presentSettings(tab: SettingsTab) {
        if let settingsWindow {
            settingsWindow.select(tab: tab)
            settingsWindow.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let controller = SettingsWindowController(initialTab: tab)
        settingsWindow = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func normalisedExtension(_ ext: String) -> String {
        switch ext.lowercased() {
        case "jpeg": return "jpg"
        case "tif": return "tiff"
        case "heif": return "heic"
        default: return ext.lowercased()
        }
    }

    private func engine(for input: URL, target: String? = nil) -> Engine? {
        switch FileKind.detect(input) {
        case .pdf:
            switch target?.lowercased() {
            case "txt", "md":
                return PDFTextEngine()
            case "html", "rtf", "rtfd", "epub", "docx", "svg":
                return PDFDocumentEngine()
            default:
                return PDFToImageEngine()
            }
        case .image:
            return ImageConvertEngine()
        case .document:
            return DocumentConversionEngine()
        case .spreadsheet:
            return SpreadsheetEngine()
        case .audio:
            return AudioEngine()
        case .video:
            return VideoEngine()
        case .subtitle:
            return SubtitleEngine()
        case .archive:
            return ArchiveEngine()
        default:
            return nil
        }
    }

    // MARK: More tools

    private func presentMoreTools(for urls: [URL]) {
        guard let input = urls.first else { return }
        let kind = FileKind.detect(input)
        guard kind == .image || kind == .pdf else {
            hud.fail("More tools are available for images and PDFs")
            return
        }
        _ = FolderAccess.shared.ensureAccess()

        let controller = MoreToolsWindowController(
            kind: kind,
            sourceName: input.lastPathComponent
        ) { [weak self] id in
            guard let self else { return }
            self.moreToolsWindow?.close()
            self.perform(
                item: WheelItem(id: id, title: id, symbol: ""),
                on: urls
            )
        }
        moreToolsWindow = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func presentMoreFormats(for urls: [URL]) {
        guard let input = urls.first else { return }
        let targets = supportedConversionTargets(for: urls)
        let remaining = Array(targets.dropFirst(6))
        guard !remaining.isEmpty else {
            hud.fail("No extra formats for this file")
            return
        }
        _ = FolderAccess.shared.ensureAccess()

        let controller = MoreFormatsWindowController(
            targets: remaining,
            sourceName: input.lastPathComponent
        ) { [weak self] id in
            guard let self else { return }
            self.moreFormatsWindow?.close()
            self.perform(
                item: WheelItem(id: id, title: id, symbol: ""),
                on: urls
            )
        }
        moreFormatsWindow = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: Archive extraction

    private func runExtractArchives(_ urls: [URL]) {
        let supported = Set(["zip", "tar", "gz", "gzip", "rar", "7z"])
        let archives = urls.filter {
            FileKind.detect($0) == .archive
                && supported.contains($0.pathExtension.lowercased())
        }
        guard !archives.isEmpty else {
            hud.fail("Select a ZIP, TAR, GZIP, RAR or 7-Zip archive")
            return
        }
        _ = FolderAccess.shared.ensureAccess()

        var destinationRoot: URL?
        if UserDefaults.standard.string(forKey: "archiveExtractionDestination") == "ask" {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.message = "Choose a folder for the extracted archives."
            panel.prompt = "Extract Here"
            guard panel.runModal() == .OK, let folder = panel.url else { return }
            destinationRoot = folder
        }

        hud.onCancel = { [weak self] in self?.extractTask?.cancel() }
        hud.show(
            title: "Extracting archive",
            subtitle: archives.count == 1
                ? archives[0].lastPathComponent
                : "1 of \(archives.count)"
        )

        extractTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var outputs: [URL] = []
            for (index, input) in archives.enumerated() {
                if Task.isCancelled {
                    self.hud.hide()
                    return
                }
                if archives.count > 1 {
                    self.hud.update(subtitle: "\(index + 1) of \(archives.count)")
                }
                do {
                    let folder = try await Task.detached(priority: .userInitiated) {
                        try ArchiveEngine.extractArchive(input, into: destinationRoot)
                    }.value
                    outputs.append(folder)
                } catch is CancellationError {
                    self.hud.hide()
                    return
                } catch {
                    self.hud.fail(error.friendlyMessage)
                    Log.write("extract failed \(input.path): \(error.localizedDescription)")
                    return
                }
            }
            guard !Task.isCancelled else {
                self.hud.hide()
                return
            }
            self.finished(outputs)
            self.hud.succeed(
                title: "Archive extracted",
                subtitle: outputs.count == 1
                    ? outputs[0].lastPathComponent
                    : "\(outputs.count) folders"
            )
            Log.write("extracted \(outputs.map(\.path))")
        }
    }

    // MARK: Crop

    private func presentCrop(for urls: [URL]) {
        guard let input = urls.first else { return }
        // Reading the file is a sandboxed operation; make sure the home-folder
        // bookmark is active before the crop window loads it.
        _ = FolderAccess.shared.ensureAccess()

        let images = urls.filter { FileKind.detect($0) == .image }
        if urls.count > 1 {
            guard images.count == urls.count else {
                hud.fail("Select only images to batch crop")
                return
            }
            guard let controller = CropWindowController(
                url: images[0], batchCount: images.count
            ) else {
                hud.fail("Couldn’t open that image")
                return
            }
            controller.onApply = { [weak self] _, normalized in
                self?.runCropBatch(images, normalized: normalized)
            }
            cropWindow = controller
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        switch FileKind.detect(input) {
        case .image:
            guard let controller = CropWindowController(url: input) else {
                hud.fail("Couldn’t open that image")
                return
            }
            controller.onApply = { [weak self] rect, _ in
                self?.runCrop(input: input, rect: rect)
            }
            cropWindow = controller
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)

        case .pdf:
            guard let controller = CropPDFWindowController(url: input) else {
                hud.fail("Couldn’t open that PDF")
                return
            }
            controller.onApply = { [weak self] spec in
                self?.runPDFCrop(input: input, spec: spec)
            }
            cropPDFWindow = controller
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)

        default:
            hud.fail("Crop for this file type is next")
        }
    }

    private func runPDFCrop(input: URL, spec: PDFCropSpec) {
        let job = Job(inputs: [input], operation: .pdfCrop(spec))
        hud.onCancel = { [weak self] in self?.pdfTask?.cancel() }
        hud.show(title: "Cropping PDF", subtitle: "Preparing…")

        pdfTask = Task { @MainActor [weak self] in
            do {
                let outputs = try await Task.detached(priority: .userInitiated) {
                    try await PDFCropEngine().run(job) { _ in }
                }.value
                self?.finished(outputs)
                self?.hud.succeed(title: "Cropped PDF", subtitle: "All pages")
                Log.write("pdf crop done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                Log.write("pdf crop failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: PDF merge + split

    private func runImagesToPDF(_ images: [URL]) {
        _ = FolderAccess.shared.ensureAccess()
        let job = Job(inputs: images, operation: .pdfFromImages)

        hud.onCancel = { [weak self] in self?.pdfTask?.cancel() }
        hud.show(title: "Creating PDF", subtitle: "\(images.count) images")

        pdfTask = Task { @MainActor [weak self] in
            do {
                let outputs = try await Task.detached(priority: .userInitiated) {
                    try await PDFFromImagesEngine().run(job) { _ in }
                }.value
                self?.finished(outputs)
                self?.hud.succeed(
                    title: "Created PDF",
                    subtitle: "\(images.count) pages"
                )
                Log.write("images to pdf done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                Log.write("images to pdf failed: \(error.localizedDescription)")
            }
        }
    }

    private func runMerge(_ urls: [URL]) {
        let pdfs = urls.filter { FileKind.detect($0) == .pdf }
        guard pdfs.count >= 2 else {
            hud.fail("Select at least two PDFs to merge")
            return
        }
        _ = FolderAccess.shared.ensureAccess()

        let job = Job(inputs: pdfs, operation: .pdfMerge)
        hud.onCancel = { [weak self] in self?.pdfTask?.cancel() }
        hud.show(title: "Merging PDFs", subtitle: "\(pdfs.count) files")

        pdfTask = Task { @MainActor [weak self] in
            do {
                let outputs = try await Task.detached(priority: .userInitiated) {
                    try await PDFMergeEngine().run(job) { _ in }
                }.value
                self?.finished(outputs)
                self?.hud.succeed(
                    title: "Merged \(pdfs.count) PDFs",
                    subtitle: "\(outputs.count) file saved"
                )
                Log.write("merge done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                Log.write("merge failed: \(error.localizedDescription)")
            }
        }
    }

    private func presentSplit(for urls: [URL]) {
        guard let input = urls.first, FileKind.detect(input) == .pdf else {
            hud.fail("Split is wired for PDFs so far")
            return
        }
        _ = FolderAccess.shared.ensureAccess()
        let controller = SplitPDFWindowController(url: input)
        controller.onApply = { [weak self] spec in
            self?.runSplit(input: input, spec: spec)
        }
        splitWindow = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func presentRedact(for urls: [URL]) {
        guard let input = urls.first else { return }
        _ = FolderAccess.shared.ensureAccess()

        switch FileKind.detect(input) {
        case .pdf:
            guard let controller = RedactPDFWindowController(url: input) else {
                hud.fail("Couldn’t open that PDF")
                return
            }
            controller.onApply = { [weak self] spec in
                self?.runRedact(input: input, spec: spec)
            }
            redactWindow = controller
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)

        case .image:
            guard let controller = RedactImageWindowController(url: input) else {
                hud.fail("Couldn’t open that image")
                return
            }
            controller.onApply = { [weak self] spec in
                self?.runRedactImage(input: input, spec: spec)
            }
            redactImageWindow = controller
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            Log.write("redact image window visible=\(controller.window?.isVisible ?? false)")

        default:
            hud.fail("Redaction is wired for images and PDFs")
        }
    }

    private func runRedactImage(input: URL, spec: ImageRedactSpec) {
        let job = Job(inputs: [input], operation: .imageRedact(spec))
        hud.onCancel = { [weak self] in self?.pdfTask?.cancel() }
        hud.show(title: "Redacting image", subtitle: "\(spec.redactions.count) boxes")

        pdfTask = Task { @MainActor [weak self] in
            do {
                let outputs = try await Task.detached(priority: .userInitiated) {
                    try await ImageRedactEngine().run(job) { _ in }
                }.value
                self?.finished(outputs)
                self?.hud.succeed(
                    title: "Redacted image",
                    subtitle: "\(spec.redactions.count) boxes blacked out"
                )
                Log.write("image redact done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                Log.write("image redact failed: \(error.localizedDescription)")
            }
        }
    }

    private func runRedact(input: URL, spec: PDFRedactSpec) {
        let job = Job(inputs: [input], operation: .pdfRedact(spec))
        hud.onCancel = { [weak self] in self?.pdfTask?.cancel() }
        hud.show(title: "Redacting PDF", subtitle: "\(spec.redactions.count) areas")

        pdfTask = Task { @MainActor [weak self] in
            do {
                let outputs = try await Task.detached(priority: .userInitiated) {
                    try await PDFRedactEngine().run(job) { _ in }
                }.value
                self?.finished(outputs)
                self?.hud.succeed(
                    title: "Redacted PDF",
                    subtitle: "\(spec.redactions.count) areas · flattened"
                )
                Log.write("redact done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                Log.write("redact failed: \(error.localizedDescription)")
            }
        }
    }

    private func presentAnnotate(for urls: [URL]) {
        guard let input = urls.first else { return }
        _ = FolderAccess.shared.ensureAccess()

        switch FileKind.detect(input) {
        case .pdf:
            guard let controller = AnnotatePDFWindowController(url: input) else {
                hud.fail("Couldn’t open that PDF")
                return
            }
            controller.onApply = { [weak self] spec in
                self?.runAnnotate(input: input, spec: spec)
            }
            annotateWindow = controller
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)

        case .image:
            guard let controller = AnnotateImageWindowController(url: input) else {
                hud.fail("Couldn’t open that image")
                return
            }
            controller.onApply = { [weak self] spec in
                self?.runAnnotateImage(input: input, spec: spec)
            }
            annotateImageWindow = controller
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)

        default:
            hud.fail("Annotation is wired for images and PDFs")
        }
    }

    private func runAnnotateImage(input: URL, spec: ImageAnnotateSpec) {
        let job = Job(inputs: [input], operation: .imageAnnotate(spec))
        hud.onCancel = { [weak self] in self?.pdfTask?.cancel() }
        hud.show(title: "Annotating image", subtitle: "\(spec.annotations.count) marks")

        pdfTask = Task { @MainActor [weak self] in
            do {
                let outputs = try await Task.detached(priority: .userInitiated) {
                    try await ImageAnnotateEngine().run(job) { _ in }
                }.value
                self?.finished(outputs)
                self?.hud.succeed(
                    title: "Annotated image",
                    subtitle: "\(spec.annotations.count) marks"
                )
                Log.write("image annotate done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                Log.write("image annotate failed: \(error.localizedDescription)")
            }
        }
    }

    private func runAnnotate(input: URL, spec: PDFAnnotateSpec) {
        let job = Job(inputs: [input], operation: .pdfAnnotate(spec))
        hud.onCancel = { [weak self] in self?.pdfTask?.cancel() }
        hud.show(title: "Annotating PDF", subtitle: "\(spec.annotations.count) marks")

        pdfTask = Task { @MainActor [weak self] in
            do {
                let outputs = try await Task.detached(priority: .userInitiated) {
                    try await PDFAnnotateEngine().run(job) { _ in }
                }.value
                self?.finished(outputs)
                self?.hud.succeed(
                    title: "Annotated PDF",
                    subtitle: "\(spec.annotations.count) marks"
                )
                Log.write("annotate done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                Log.write("annotate failed: \(error.localizedDescription)")
            }
        }
    }

    private func presentOrganize(for urls: [URL]) {
        guard let input = urls.first, FileKind.detect(input) == .pdf else {
            hud.fail("Organize is wired for PDFs so far")
            return
        }
        _ = FolderAccess.shared.ensureAccess()
        guard let controller = OrganizePDFWindowController(url: input) else {
            hud.fail("Couldn’t open that PDF")
            return
        }
        controller.onApply = { [weak self] spec in
            self?.runOrganize(input: input, spec: spec)
        }
        organizeWindow = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func runOrganize(input: URL, spec: PDFOrganizeSpec) {
        let job = Job(inputs: [input], operation: .pdfOrganize(spec))
        hud.onCancel = { [weak self] in self?.pdfTask?.cancel() }
        hud.show(title: "Organizing PDF", subtitle: "Preparing…")

        pdfTask = Task { @MainActor [weak self] in
            do {
                let outputs = try await Task.detached(priority: .userInitiated) {
                    try await PDFOrganizeEngine().run(job) { _ in }
                }.value
                self?.finished(outputs)
                self?.hud.succeed(
                    title: "Page order saved",
                    subtitle: "\(spec.pages.count) pages"
                )
                Log.write("organize done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                Log.write("organize failed: \(error.localizedDescription)")
            }
        }
    }

    private func runSplit(input: URL, spec: PDFSplitSpec) {
        let job = Job(inputs: [input], operation: .pdfSplit(spec))
        hud.onCancel = { [weak self] in self?.pdfTask?.cancel() }
        hud.show(title: "Splitting PDF", subtitle: "Preparing…")

        pdfTask = Task { @MainActor [weak self] in
            do {
                let outputs = try await Task.detached(priority: .userInitiated) {
                    try await PDFSplitEngine().run(job) { _ in }
                }.value
                self?.finished(outputs)
                self?.hud.succeed(
                    title: "Split into \(outputs.count) parts",
                    subtitle: "Saved in a new folder"
                )
                Log.write("split done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                Log.write("split failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Metadata

    private func presentMetadata(for urls: [URL]) {
        guard let input = urls.first else { return }
        guard FileKind.detect(input) == .image else {
            hud.fail("Metadata for this file type is next")
            return
        }
        _ = FolderAccess.shared.ensureAccess()
        let controller = MetadataWindowController(url: input)
        controller.onStrip = { [weak self] in
            self?.runStripMetadata(input: input)
        }
        metadataWindow = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func runStripMetadata(input: URL) {
        let ext = ["jpg", "jpeg", "png", "heic", "tiff"]
            .contains(input.pathExtension.lowercased())
            ? input.pathExtension.lowercased()
            : "jpg"
        let spec = MetadataSpec(action: .strip, format: ext)
        let job = Job(inputs: [input], operation: .metadata(spec))

        hud.onCancel = { [weak self] in self?.metadataTask?.cancel() }
        hud.show(title: "Stripping metadata", subtitle: "Preparing…")

        metadataTask = Task { @MainActor [weak self] in
            do {
                let outputs = try await Task.detached(priority: .userInitiated) {
                    try await ImageMetadataEngine().run(job) { _ in }
                }.value
                self?.finished(outputs)
                self?.hud.succeed(title: "Metadata removed", subtitle: "1 of 1 saved")
                Log.write("metadata strip done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                Log.write("metadata strip failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Photo editor

    private func presentPhotoEditor(for input: URL) {
        _ = FolderAccess.shared.ensureAccess()
        guard let controller = PhotoEditorWindowController(url: input) else {
            hud.fail("Couldn’t open that image")
            return
        }
        controller.onApply = { [weak self] spec in
            self?.runAdjustImage(input: input, spec: spec)
        }
        photoEditorWindow = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func runAdjustImage(input: URL, spec: ImageAdjustSpec) {
        let job = Job(inputs: [input], operation: .imageAdjust(spec))
        hud.onCancel = { [weak self] in self?.cropTask?.cancel() }
        hud.show(title: "Editing photo", subtitle: "Preparing…")

        cropTask = Task { @MainActor [weak self] in
            do {
                let outputs = try await Task.detached(priority: .userInitiated) {
                    try await ImageAdjustEngine().run(job) { _ in }
                }.value
                self?.finished(outputs)
                self?.hud.succeed(title: "Edited image", subtitle: "1 of 1 saved")
                Log.write("edit done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                Log.write("edit failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Read QR

    private func runPDFA(input: URL) {
        hud.onCancel = { [weak self] in self?.pdfaTask?.cancel() }
        hud.show(title: "Converting to PDF/A-2B", subtitle: input.lastPathComponent)
        pdfaTask = Task { @MainActor [weak self] in
            do {
                let output = try await Task.detached(priority: .userInitiated) {
                    try PDFAConverter.convert(input)
                }.value
                guard !Task.isCancelled else { return }
                self?.lastOutputs = [output]
                self?.hud.succeed(
                    title: "Converted to PDF/A-2B",
                    subtitle: output.lastPathComponent
                )
                Reveal.ifEnabled([output])
                Log.write("pdfa created \(output.path)")
            } catch {
                self?.hud.fail(error.localizedDescription)
                Log.write("pdfa failed: \(error.localizedDescription)")
            }
        }
    }

    private func runReadQR(input: URL) {
        _ = FolderAccess.shared.ensureAccess()
        hud.onCancel = { [weak self] in self?.qrTask?.cancel() }
        hud.show(title: "Reading QR", subtitle: "On-device")

        qrTask = Task { @MainActor [weak self] in
            let values = await Task.detached(priority: .userInitiated) {
                QRCodeReader.decode(at: input)
            }.value

            guard let self else { return }
            self.hud.hide()

            let controller = QRResultWindowController(
                values: values, source: input
            )
            self.qrWindow = controller
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            Log.write("qr read \(values.count)")
        }
    }

    // MARK: Remove background

    private func runRemoveBG(input: URL) {
        _ = FolderAccess.shared.ensureAccess()
        let job = Job(inputs: [input], operation: .imageRemoveBG)
        hud.onCancel = { [weak self] in self?.cropTask?.cancel() }
        hud.show(title: "Removing background", subtitle: "On-device")

        cropTask = Task { @MainActor [weak self] in
            do {
                let outputs = try await Task.detached(priority: .userInitiated) {
                    try await ImageRemoveBGEngine().run(job) { _ in }
                }.value
                self?.finished(outputs)
                self?.hud.succeed(
                    title: "Background removed",
                    subtitle: "Transparent PNG"
                )
                Log.write("remove bg done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                Log.write("remove bg failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Collage

    private func presentCollage(for urls: [URL]) {
        let images = urls.filter { FileKind.detect($0) == .image }
        guard images.count >= 2, images.count == urls.count else {
            hud.fail("Select two or more images to make a collage")
            return
        }
        _ = FolderAccess.shared.ensureAccess()
        guard let controller = CollageImageWindowController(urls: images) else {
            hud.fail("Couldn’t open those images")
            return
        }
        controller.onApply = { [weak self] spec in
            self?.runCollage(images, spec: spec)
        }
        collageWindow = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func runCollage(_ images: [URL], spec: ImageCollageSpec) {
        let job = Job(inputs: images, operation: .imageCollage(spec))
        hud.onCancel = { [weak self] in self?.cropTask?.cancel() }
        hud.show(title: "Building collage", subtitle: "\(images.count) images")

        cropTask = Task { @MainActor [weak self] in
            do {
                let outputs = try await Task.detached(priority: .userInitiated) {
                    try await ImageCollageEngine().run(job) { _ in }
                }.value
                self?.finished(outputs)
                self?.hud.succeed(
                    title: "Collage",
                    subtitle: "\(images.count) images"
                )
                Log.write("collage done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                Log.write("collage failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Add background

    private func presentFrame(for urls: [URL]) {
        guard let input = urls.first else { return }
        _ = FolderAccess.shared.ensureAccess()

        switch FileKind.detect(input) {
        case .image:
            guard let controller = FrameImageWindowController(url: input) else {
                hud.fail("Couldn’t open that image")
                return
            }
            controller.onApply = { [weak self] spec in
                self?.runFrame(input: input, spec: spec)
            }
            frameWindow = controller
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)

        case .pdf:
            guard let controller = FramePDFWindowController(url: input) else {
                hud.fail("Couldn’t open that PDF")
                return
            }
            controller.onApply = { [weak self] spec in
                self?.runPDFFrame(input: input, spec: spec)
            }
            framePDFWindow = controller
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)

        default:
            hud.fail("Add BG is wired for images and PDFs")
        }
    }

    private func runPDFFrame(input: URL, spec: PDFFrameSpec) {
        let job = Job(inputs: [input], operation: .pdfFrame(spec))
        hud.onCancel = { [weak self] in self?.pdfTask?.cancel() }
        hud.show(title: "Framing PDF", subtitle: "Preparing…")

        pdfTask = Task { @MainActor [weak self] in
            do {
                let outputs = try await Task.detached(priority: .userInitiated) {
                    try await PDFFrameEngine().run(job) { _ in }
                }.value
                self?.finished(outputs)
                self?.hud.succeed(title: "Framed PDF", subtitle: "All pages")
                Log.write("pdf frame done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                Log.write("pdf frame failed: \(error.localizedDescription)")
            }
        }
    }

    private func runFrame(input: URL, spec: ImageFrameSpec) {
        let job = Job(inputs: [input], operation: .imageFrame(spec))
        hud.onCancel = { [weak self] in self?.frameTask?.cancel() }
        hud.show(title: "Adding background", subtitle: "Preparing…")

        frameTask = Task { @MainActor [weak self] in
            do {
                let outputs = try await Task.detached(priority: .userInitiated) {
                    try await ImageFrameEngine().run(job) { _ in }
                }.value
                self?.finished(outputs)
                self?.hud.succeed(title: "Framed image", subtitle: "1 of 1 saved")
                Log.write("frame done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                Log.write("frame failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Compress

    private func presentCompress(for urls: [URL]) {
        guard let input = urls.first else { return }
        _ = FolderAccess.shared.ensureAccess()

        switch FileKind.detect(input) {
        case .image:
            let controller = CompressWindowController(url: input)
            controller.onApply = { [weak self] spec in
                self?.runCompress(input: input, spec: spec)
            }
            compressWindow = controller
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)

        case .pdf:
            let controller = CompressPDFWindowController(url: input)
            controller.onApply = { [weak self] spec in
                self?.runPDFCompress(input: input, spec: spec)
            }
            compressPDFWindow = controller
            controller.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)

        default:
            hud.fail("Compression for this file type is next")
        }
    }

    private func runPDFCompress(input: URL, spec: PDFCompressSpec) {
        let job = Job(inputs: [input], operation: .pdfCompress(spec))
        hud.onCancel = { [weak self] in self?.pdfTask?.cancel() }
        hud.show(title: "Compressing PDF", subtitle: "Preparing…")

        pdfTask = Task { @MainActor [weak self] in
            do {
                let outputs = try await Task.detached(priority: .userInitiated) {
                    try await PDFCompressEngine().run(job) { _ in }
                }.value
                self?.finished(outputs)
                self?.announceCompression(input: input, outputs: outputs)
                Log.write("pdf compress done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                Log.write("pdf compress failed: \(error.localizedDescription)")
            }
        }
    }

    private func runCompress(input: URL, spec: CompressSpec) {
        let job = Job(inputs: [input], operation: .compress(spec))

        hud.onCancel = { [weak self] in self?.compressTask?.cancel() }
        hud.show(title: "Compressing", subtitle: "Preparing…")

        compressTask = Task { @MainActor [weak self] in
            do {
                let outputs = try await Task.detached(priority: .userInitiated) {
                    try await ImageCompressEngine().run(job) { _ in }
                }.value
                self?.finished(outputs)
                self?.announceCompression(input: input, outputs: outputs)
                Log.write("compress done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                Log.write("compress failed: \(error.localizedDescription)")
            }
        }
    }

    private func announceCompression(input: URL, outputs: [URL]) {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file

        let inBytes = ((try? FileManager.default.attributesOfItem(atPath: input.path))?[.size] as? NSNumber)?.intValue ?? 0
        guard let output = outputs.first else {
            hud.succeed(title: "Compressed", subtitle: "")
            return
        }
        let outBytes = ((try? FileManager.default.attributesOfItem(atPath: output.path))?[.size] as? NSNumber)?.intValue ?? 0
        let size = formatter.string(fromByteCount: Int64(outBytes))

        if inBytes > 0, outBytes < inBytes {
            let saved = Int(((1 - Double(outBytes) / Double(inBytes)) * 100).rounded())
            hud.succeed(title: "Compressed", subtitle: "\(size) · −\(saved)%")
        } else {
            hud.succeed(title: "Compressed", subtitle: "\(size) · already small")
        }
    }

    // MARK: Resize + rotate

    private func presentAdjust(
        for urls: [URL],
        mode: ImageAdjustWindowController.Mode
    ) {
        guard let input = urls.first, FileKind.detect(input) == .image else {
            hud.fail("Resize and rotate are wired for images so far")
            return
        }
        _ = FolderAccess.shared.ensureAccess()
        guard let controller = ImageAdjustWindowController(url: input, mode: mode) else {
            hud.fail("Couldn’t open that image")
            return
        }
        controller.onApply = { [weak self] spec in
            self?.runAdjust(input: input, spec: spec)
        }
        adjustWindow = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func runAdjust(input: URL, spec: ImageEditSpec) {
        let job = Job(inputs: [input], operation: .edit(spec))
        let verb: String
        switch spec.suffix {
        case "Resized": verb = "Resizing"
        case "Rotated": verb = "Rotating"
        default: verb = "Editing"
        }

        hud.onCancel = { [weak self] in self?.adjustTask?.cancel() }
        hud.show(title: verb, subtitle: "Preparing…")

        adjustTask = Task { @MainActor [weak self] in
            do {
                let outputs = try await Task.detached(priority: .userInitiated) {
                    try await ImageEditEngine().run(job) { _ in }
                }.value
                self?.finished(outputs)
                self?.hud.succeed(title: "\(spec.suffix) image", subtitle: "1 of 1 saved")
                Log.write("adjust done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                Log.write("adjust failed: \(error.localizedDescription)")
            }
        }
    }

    private func runCropBatch(_ images: [URL], normalized: PDFRect) {
        let job = Job(
            inputs: images,
            operation: .imageCropBatch(ImageCropBatchSpec(normalized: normalized))
        )
        hud.onCancel = { [weak self] in self?.cropTask?.cancel() }
        hud.show(title: "Cropping \(images.count) images", subtitle: "Preparing…")

        cropTask = Task { @MainActor [weak self] in
            do {
                let outputs = try await Task.detached(priority: .userInitiated) {
                    try await ImageCropBatchEngine().run(job) { _ in }
                }.value
                self?.finished(outputs)
                self?.hud.succeed(
                    title: "Batch crop",
                    subtitle: "\(outputs.count) images"
                )
                Log.write("batch crop done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                Log.write("batch crop failed: \(error.localizedDescription)")
            }
        }
    }

    private func runCrop(input: URL, rect: CGRect) {
        let ext = ["jpg", "jpeg", "png", "heic", "tiff"]
            .contains(input.pathExtension.lowercased())
            ? input.pathExtension.lowercased()
            : "jpg"
        let spec = CropSpec(
            x: Int(rect.minX),
            y: Int(rect.minY),
            width: Int(rect.width),
            height: Int(rect.height),
            format: ext
        )
        let job = Job(inputs: [input], operation: .crop(spec))

        hud.onCancel = { [weak self] in self?.cropTask?.cancel() }
        hud.show(title: "Cropping", subtitle: "Preparing…")

        cropTask = Task { @MainActor [weak self] in
            do {
                let outputs = try await Task.detached(priority: .userInitiated) {
                    try await ImageCropEngine().run(job) { _ in }
                }.value
                self?.finished(outputs)
                self?.hud.succeed(title: "Cropped", subtitle: "1 of 1 saved")
                Log.write("crop done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                Log.write("crop failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Windows

    @objc private func showWelcome() {
        showOnboarding(page: 0)
    }

    private func showOnboarding(page: Int) {
        if let onboardingWindow {
            onboardingWindow.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let controller = OnboardingWindowController(initialPage: page)
        controller.onFinish = { [weak self] in
            UserDefaults.standard.set(true, forKey: "hasSeenWelcome")
            self?.onboardingWindow = nil
        }
        onboardingWindow = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func grantFolderAccess() {
        FolderAccess.shared.prompt()
    }

    @objc private func menuBarVisibilityChanged(_ note: Notification) {
        let visible = note.object as? Bool ?? true
        applyMenuBarVisibility(visible, showSettingsIfHidden: false)
    }

    @objc private func showOnboardingFromSettings() {
        showOnboarding(page: 0)
    }

    private func applyMenuBarVisibility(_ visible: Bool, showSettingsIfHidden: Bool) {
        Log.write("menu bar icon visible=\(visible)")
        showMenuBarIcon = visible
        statusItem?.isVisible = visible
        if visible {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
            if showSettingsIfHidden {
                showSettings()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !showMenuBarIcon {
            showSettings()
        }
        return true
    }

    @objc private func revealLast() {
        guard !lastOutputs.isEmpty else {
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting(lastOutputs)
    }
}
