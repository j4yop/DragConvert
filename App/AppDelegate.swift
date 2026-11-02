import AppKit
import SwiftUI
import DragSense
import CapabilityGraph
import WheelUI
import JobCore
import EngineKit
import PDFEngine
import ImageEngine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let monitor = DragMonitor()
    private let wheel = WheelController()
    private var welcomeWindow: NSWindow?
    private var lastOutputs: [URL] = []

    private var lastSession: FileDragSession?
    private var lastSignature: String?
    private var lastHoveredID: String?
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
    private var qrWindow: QRResultWindowController?
    private var qrTask: Task<Void, Never>?
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
        setUpStatusItem()

        wheel.onDrop = { [weak self] item, urls in
            Log.write("drop via draggingDestination \(item.id)")
            self?.perform(item: item, on: urls)
        }

        wheel.onActivate = { [weak self] item in
            guard let self, let files = self.lastSession?.files, !files.isEmpty else { return }
            Log.write("keyboard activate \(item.id)")
            self.perform(item: item, on: files)
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

        if CommandLine.arguments.contains("--wheel-demo") {
            let items = Capabilities.items(mode: .actions, kind: .pdf)
            wheel.show(items: items, at: NSEvent.mouseLocation, label: "Panel.pdf")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                Log.write("wheel demo key=\(self.wheel.isKeyWindow) visible=\(self.wheel.visible) appActive=\(NSApp.isActive) front=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil")")
            }
        }

        if !UserDefaults.standard.bool(forKey: "hasSeenWelcome") {
            showWelcome()
            UserDefaults.standard.set(true, forKey: "hasSeenWelcome")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            FolderAccess.shared.ensureAccess()
        }
    }

    // MARK: Menu bar

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "◎"
        item.button?.toolTip = "Drag a file, then hold ⇧ to convert, ⌥⌘ for tools, ⌃ for actions"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "How it works…", action: #selector(showWelcome), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Grant Folder Access…", action: #selector(grantFolderAccess), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Reveal Last Result", action: #selector(revealLast), keyEquivalent: "r"))
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
        lastSession = session

        guard let mode = WheelMode.from(session.modifiers) else {
            wheel.hide()
            return
        }

        let kind = FileKind.commonKind(of: session.files) ?? .unknown
        if kind == .unknown && mode != .actions {
            wheel.hide()
            return
        }

        let extensionName = session.files.first?.pathExtension
        let items = Capabilities.items(
            mode: mode,
            kind: kind,
            inputExtension: extensionName
        )
        let label = session.files.count == 1
            ? session.files[0].lastPathComponent
            : "\(session.files.count) files"

        if lastSignature != session.signature {
            lastSignature = session.signature
            Log.write("drag \(session.files.count) file(s) mode=\(mode.rawValue) kind=\(kind.rawValue) items=\(items.count)")
        }

        wheel.show(items: items, at: session.point, label: label)
        wheel.updateHover(atScreenPoint: session.point)

        let hovered = wheel.hoveredItem?.id
        if hovered != lastHoveredID {
            lastHoveredID = hovered
            Log.write("hover \(hovered ?? "none")")
        }
    }

    private func finishDrag() {
        Log.write("drag ended, visible=\(wheel.visible) hovered=\(wheel.hoveredItem?.id ?? "none") locked=\(wheel.isLocked)")
        if wheel.isLocked {
            // A keyboard choice already ran; keep the panel up only long
            // enough to absorb Finder's drop, then close.
            wheel.hide()
            lastSession = nil
            lastSignature = nil
            lastHoveredID = nil
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
        lastSession = nil
        lastSignature = nil
        lastHoveredID = nil
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

        if item.id == "tool:readqr" {
            guard let input = urls.first, FileKind.detect(input) == .image else {
                hud.fail("Read QR is wired for images so far")
                return
            }
            runReadQR(input: input)
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

        guard item.id.hasPrefix("convert:") else {
            NSSound.beep()
            Log.write("not implemented: \(item.id)")
            hud.fail("\(item.title) isn’t built yet")
            return
        }

        let target = String(item.id.dropFirst("convert:".count))
        let files = urls

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
        statusItem?.button?.title = "◉"

        batchTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var outputs: [URL] = []

            for (index, input) in files.enumerated() {
                if Task.isCancelled { break }

                let job = Job(inputs: [input], operation: .convert(to: target))
                guard let engine = self.engine(for: input), engine.canHandle(job) else {
                    self.hud.fail("Can’t convert \(input.lastPathComponent) to \(target.uppercased())")
                    self.statusItem?.button?.title = "◎"
                    return
                }

                if files.count > 1 {
                    self.hud.update(subtitle: "\(index + 1) of \(files.count)")
                }

                Log.write("job start \(input.path) → \(target)")
                let task = Task.detached(priority: .userInitiated) {
                    try await engine.run(job) { _ in }
                }
                self.engineTask = task

                do {
                    let result = try await task.value
                    outputs.append(contentsOf: result)
                    self.hud.update(
                        subtitle: files.count == 1
                            ? "Saving…"
                            : "\(index + 1) of \(files.count) saved"
                    )
                } catch is CancellationError {
                    self.hud.hide()
                    self.statusItem?.button?.title = "◎"
                    Log.write("cancelled")
                    return
                } catch {
                    self.hud.fail(error.friendlyMessage)
                    self.statusItem?.button?.title = "◎"
                    NSSound.beep()
                    Log.write("job failed \(input.path): \(error.localizedDescription)")
                    return
                }
            }

            if Task.isCancelled {
                self.hud.hide()
                self.statusItem?.button?.title = "◎"
                return
            }

            self.lastOutputs = outputs
            self.statusItem?.button?.title = "◎"
            self.hud.succeed(
                title: "Converted to \(target.uppercased())",
                subtitle: "\(files.count) of \(files.count) saved"
            )
            NSSound(named: "Glass")?.play()
            Log.write("batch done \(outputs.map(\.path))")
        }
    }

    private func engine(for input: URL) -> Engine? {
        switch FileKind.detect(input) {
        case .pdf: return PDFToImageEngine()
        case .image: return ImageConvertEngine()
        default: return nil
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
                self?.lastOutputs = outputs
                self?.hud.succeed(title: "Cropped PDF", subtitle: "All pages")
                NSSound(named: "Glass")?.play()
                Log.write("pdf crop done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                NSSound.beep()
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
                self?.lastOutputs = outputs
                self?.hud.succeed(
                    title: "Created PDF",
                    subtitle: "\(images.count) pages"
                )
                NSSound(named: "Glass")?.play()
                Log.write("images to pdf done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                NSSound.beep()
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
                self?.lastOutputs = outputs
                self?.hud.succeed(
                    title: "Merged \(pdfs.count) PDFs",
                    subtitle: "\(outputs.count) file saved"
                )
                NSSound(named: "Glass")?.play()
                Log.write("merge done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                NSSound.beep()
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
                self?.lastOutputs = outputs
                self?.hud.succeed(
                    title: "Redacted image",
                    subtitle: "\(spec.redactions.count) boxes blacked out"
                )
                NSSound(named: "Glass")?.play()
                Log.write("image redact done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                NSSound.beep()
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
                self?.lastOutputs = outputs
                self?.hud.succeed(
                    title: "Redacted PDF",
                    subtitle: "\(spec.redactions.count) areas · flattened"
                )
                NSSound(named: "Glass")?.play()
                Log.write("redact done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                NSSound.beep()
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
                self?.lastOutputs = outputs
                self?.hud.succeed(
                    title: "Annotated image",
                    subtitle: "\(spec.annotations.count) marks"
                )
                NSSound(named: "Glass")?.play()
                Log.write("image annotate done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                NSSound.beep()
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
                self?.lastOutputs = outputs
                self?.hud.succeed(
                    title: "Annotated PDF",
                    subtitle: "\(spec.annotations.count) marks"
                )
                NSSound(named: "Glass")?.play()
                Log.write("annotate done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                NSSound.beep()
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
                self?.lastOutputs = outputs
                self?.hud.succeed(
                    title: "Page order saved",
                    subtitle: "\(spec.pages.count) pages"
                )
                NSSound(named: "Glass")?.play()
                Log.write("organize done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                NSSound.beep()
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
                self?.lastOutputs = outputs
                self?.hud.succeed(
                    title: "Split into \(outputs.count) parts",
                    subtitle: "Saved in a new folder"
                )
                NSSound(named: "Glass")?.play()
                Log.write("split done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                NSSound.beep()
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
                self?.lastOutputs = outputs
                self?.hud.succeed(title: "Metadata removed", subtitle: "1 of 1 saved")
                NSSound(named: "Glass")?.play()
                Log.write("metadata strip done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                NSSound.beep()
                Log.write("metadata strip failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Read QR

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
            if values.isEmpty { NSSound.beep() }

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
                self?.lastOutputs = outputs
                self?.hud.succeed(
                    title: "Background removed",
                    subtitle: "Transparent PNG"
                )
                NSSound(named: "Glass")?.play()
                Log.write("remove bg done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                NSSound.beep()
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
                self?.lastOutputs = outputs
                self?.hud.succeed(
                    title: "Collage",
                    subtitle: "\(images.count) images"
                )
                NSSound(named: "Glass")?.play()
                Log.write("collage done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                NSSound.beep()
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
                self?.lastOutputs = outputs
                self?.hud.succeed(title: "Framed PDF", subtitle: "All pages")
                NSSound(named: "Glass")?.play()
                Log.write("pdf frame done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                NSSound.beep()
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
                self?.lastOutputs = outputs
                self?.hud.succeed(title: "Framed image", subtitle: "1 of 1 saved")
                NSSound(named: "Glass")?.play()
                Log.write("frame done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                NSSound.beep()
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
                self?.lastOutputs = outputs
                self?.announceCompression(input: input, outputs: outputs)
                NSSound(named: "Glass")?.play()
                Log.write("pdf compress done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                NSSound.beep()
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
                self?.lastOutputs = outputs
                self?.announceCompression(input: input, outputs: outputs)
                NSSound(named: "Glass")?.play()
                Log.write("compress done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                NSSound.beep()
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
                self?.lastOutputs = outputs
                self?.hud.succeed(title: "\(spec.suffix) image", subtitle: "1 of 1 saved")
                NSSound(named: "Glass")?.play()
                Log.write("adjust done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                NSSound.beep()
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
                self?.lastOutputs = outputs
                self?.hud.succeed(
                    title: "Batch crop",
                    subtitle: "\(outputs.count) images"
                )
                NSSound(named: "Glass")?.play()
                Log.write("batch crop done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                NSSound.beep()
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
                self?.lastOutputs = outputs
                self?.hud.succeed(title: "Cropped", subtitle: "1 of 1 saved")
                NSSound(named: "Glass")?.play()
                Log.write("crop done \(outputs.map(\.path))")
            } catch {
                self?.hud.fail(error.friendlyMessage)
                NSSound.beep()
                Log.write("crop failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Windows

    @objc private func showWelcome() {
        if let window = welcomeWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 430),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: WelcomeView())
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        welcomeWindow = window
    }

    @objc private func grantFolderAccess() {
        FolderAccess.shared.prompt()
    }

    @objc private func revealLast() {
        guard !lastOutputs.isEmpty else {
            NSSound.beep()
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting(lastOutputs)
    }
}
