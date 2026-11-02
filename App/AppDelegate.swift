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

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.write("launched")
        setUpStatusItem()

        wheel.onDrop = { [weak self] item, urls in
            Log.write("drop via draggingDestination \(item.id)")
            self?.perform(item: item, on: urls)
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
        Log.write("drag ended, visible=\(wheel.visible) hovered=\(wheel.hoveredItem?.id ?? "none")")

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

        guard item.id.hasPrefix("convert:") else {
            NSSound.beep()
            Log.write("not implemented: \(item.id)")
            hud.fail("\(item.title) isn’t built yet")
            return
        }

        let target = String(item.id.dropFirst("convert:".count))
        let files = urls

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
