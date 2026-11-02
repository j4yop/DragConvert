import AppKit

/// One continuous drag, as observed from outside the app that owns it.
public struct FileDragSession: Sendable {
    public let files: [URL]
    public let point: CGPoint
    public let modifiers: NSEvent.ModifierFlags

    public init(files: [URL], point: CGPoint, modifiers: NSEvent.ModifierFlags) {
        self.files = files
        self.point = point
        self.modifiers = modifiers
    }

    public var signature: String {
        let paths = files.map(\.path).joined(separator: "|")
        return "\(paths)#\(modifiers.rawValue)"
    }
}

/// Polls the system drag pasteboard and the left mouse button.
///
/// No event tap, no Accessibility permission:
/// - `CGEventSource.buttonState` tells us the button is down.
/// - `NSPasteboard(name: .drag)` exposes the dragged files (verified working
///   inside App Sandbox: the wheel shows the file name in the centre).
/// - `NSEvent.modifierFlags` is a global static.
public final class DragMonitor {
    public var onChange: ((FileDragSession?) -> Void)?

    private var timer: Timer?
    private var current: FileDragSession?

    public init() {}

    public func start() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        current = nil
    }

    private func tick() {
        guard CGEventSource.buttonState(.combinedSessionState, button: .left) else {
            finishDrag()
            return
        }

        let files = readFileURLs()
        guard !files.isEmpty else {
            finishDrag()
            return
        }

        let session = FileDragSession(
            files: files,
            point: NSEvent.mouseLocation,
            modifiers: NSEvent.modifierFlags
        )

        if let old = current, old.signature == session.signature, old.point == session.point {
            return
        }
        current = session
        onChange?(session)
    }

    private func finishDrag() {
        guard current != nil else { return }
        current = nil
        onChange?(nil)
    }

    private func readFileURLs() -> [URL] {
        let pb = NSPasteboard(name: .drag)
        guard let types = pb.types else { return [] }

        if types.contains(.fileURL) {
            let objects = pb.readObjects(
                forClasses: [NSURL.self],
                options: [.urlReadingFileURLsOnly: true]
            ) ?? []
            let urls = objects.compactMap { ($0 as? NSURL).map { $0 as URL } }
            if !urls.isEmpty { return urls }
        }

        // Some drag sources (notably older Dock/Finder paths) still publish
        // the legacy filename list rather than a modern fileURL.
        if let paths = pb.propertyList(
            forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")
        ) as? [String] {
            return paths.map { URL(fileURLWithPath: $0) }
        }

        if let string = pb.string(forType: .fileURL),
           let url = URL(string: string),
           url.isFileURL {
            return [url]
        }

        return []
    }
}
