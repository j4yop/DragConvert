import AppKit
import JobCore

final class RedactCanvas: NSView {
    var image: CGImage? {
        didSet { needsDisplay = true }
    }

    var redactions: [PDFRect] = [] {
        didSet { needsDisplay = true }
    }

    var pageIndex: Int = 0
    var onAdd: ((PDFRect) -> Void)?

    private var dragStart: CGPoint?
    private var draftRect: CGRect?

    override var isOpaque: Bool { true }

    private var imageRect: CGRect {
        guard let image else { return .zero }
        let available = bounds.insetBy(dx: 16, dy: 16)
        guard available.width > 1, available.height > 1 else { return .zero }
        let ratio = CGFloat(image.width) / CGFloat(image.height)
        var width = available.width
        var height = width / ratio
        if height > available.height {
            height = available.height
            width = height * ratio
        }
        return CGRect(
            x: available.midX - width / 2,
            y: available.midY - height / 2,
            width: width, height: height
        )
    }

    private func normalisedRect(from start: CGPoint, to end: CGPoint) -> PDFRect {
        let rect = imageRect
        guard rect.width > 0, rect.height > 0 else {
            return PDFRect(x: 0, y: 0, width: 0, height: 0)
        }
        let ax = Double((start.x - rect.minX) / rect.width)
        let ay = Double((rect.maxY - start.y) / rect.height)
        let bx = Double((end.x - rect.minX) / rect.width)
        let by = Double((rect.maxY - end.y) / rect.height)
        return PDFRect(
            x: min(ax, bx),
            y: min(ay, by),
            width: abs(bx - ax),
            height: abs(by - ay)
        )
    }

    private func viewRect(_ rect: PDFRect) -> CGRect {
        let base = imageRect
        return CGRect(
            x: base.minX + CGFloat(rect.x) * base.width,
            y: base.maxY - CGFloat(rect.y + rect.height) * base.height,
            width: CGFloat(rect.width) * base.width,
            height: CGFloat(rect.height) * base.height
        )
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard imageRect.contains(point) else { return }
        dragStart = point
        draftRect = CGRect(origin: point, size: .zero)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        let point = convert(event.locationInWindow, from: nil)
        draftRect = CGRect(
            x: min(start.x, point.x),
            y: min(start.y, point.y),
            width: abs(point.x - start.x),
            height: abs(point.y - start.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            dragStart = nil
            draftRect = nil
            needsDisplay = true
        }
        guard let start = dragStart else { return }
        let end = convert(event.locationInWindow, from: nil)
        let rect = normalisedRect(from: start, to: end)
        guard rect.width > 0.005, rect.height > 0.005 else { return }
        onAdd?(rect)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        bounds.fill()

        guard let image else { return }
        NSGraphicsContext.current?.cgContext.draw(image, in: imageRect)

        for redaction in redactions {
            let rect = viewRect(redaction)
            NSColor.black.withAlphaComponent(0.85).setFill()
            NSBezierPath(rect: rect).fill()
            NSColor.systemRed.setStroke()
            let border = NSBezierPath(rect: rect)
            border.lineWidth = 1
            border.stroke()
        }

        if let draft = draftRect {
            NSColor.black.withAlphaComponent(0.5).setFill()
            NSBezierPath(rect: draft).fill()
            NSColor.systemRed.setStroke()
            let border = NSBezierPath(rect: draft)
            border.lineWidth = 1
            border.setLineDash([4, 3], count: 2, phase: 0)
            border.stroke()
        }
    }
}
