import AppKit

/// Image preview with a draggable crop rectangle.
/// Four corner handles, move inside the rect, optional aspect lock.
final class CropCanvas: NSView {
    var image: CGImage? {
        didSet { needsDisplay = true; reset() }
    }

    var aspect: CGFloat? {
        didSet { applyAspect() }
    }

    var onCropChanged: ((CGRect) -> Void)?

    private(set) var cropRect: CGRect = .zero

    private enum Handle { case topLeft, topRight, bottomRight, bottomLeft, move, none }
    private var dragHandle: Handle = .none
    private var dragStart: NSPoint = .zero
    private var startRect: CGRect = .zero

    private let handleSize: CGFloat = 10
    private let minSize: CGFloat = 32

    override var acceptsFirstResponder: Bool { true }

    override func layout() {
        super.layout()
        // The image is assigned before the window lays out; initialise the
        // crop rectangle once we know the view's real size.
        if cropRect == .zero, image != nil, bounds.width > 0, bounds.height > 0 {
            reset()
        }
    }

    // MARK: Geometry

    private var imageRect: CGRect {
        guard let image else { return .zero }
        let available = bounds.insetBy(dx: 14, dy: 14)
        guard available.width > 0, available.height > 0 else { return .zero }
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
            width: width,
            height: height
        )
    }

    func reset() {
        guard image != nil else { cropRect = .zero; return }
        let r = imageRect
        cropRect = r.insetBy(dx: r.width * 0.1, dy: r.height * 0.1)
        if aspect != nil { applyAspect() }
        notify()
    }

    private func applyAspect() {
        guard let aspect, cropRect.width > 0, imageRect.width > 0 else { return }
        let center = CGPoint(x: cropRect.midX, y: cropRect.midY)
        var width = cropRect.width
        var height = width / aspect
        if height > imageRect.height {
            height = imageRect.height
            width = height * aspect
        }
        if width > imageRect.width {
            width = imageRect.width
            height = width / aspect
        }
        var rect = CGRect(
            x: center.x - width / 2,
            y: center.y - height / 2,
            width: width, height: height
        )
        rect = clamp(rect)
        cropRect = rect
        notify()
    }

    private func clamp(_ rect: CGRect) -> CGRect {
        let b = imageRect
        var r = rect
        r.size.width = min(max(minSize, r.width), b.width)
        r.size.height = min(max(minSize, r.height), b.height)
        r.origin.x = min(max(r.minX, b.minX), b.maxX - r.width)
        r.origin.y = min(max(r.minY, b.minY), b.maxY - r.height)
        return r
    }

    private func notify() {
        needsDisplay = true
        onCropChanged?(cropRect)
    }

    /// Crop rect in image pixels, top-left origin (CGImage.cropping space).
    func pixelRect() -> CGRect {
        guard let image, imageRect.width > 0 else { return .zero }
        let scale = CGFloat(image.width) / imageRect.width
        return CGRect(
            x: ((cropRect.minX - imageRect.minX) * scale).rounded(),
            y: ((imageRect.maxY - cropRect.maxY) * scale).rounded(),
            width: (cropRect.width * scale).rounded(),
            height: (cropRect.height * scale).rounded()
        )
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()

        guard let image else { return }
        NSGraphicsContext.current?.cgContext.draw(image, in: imageRect)

        let scrim = NSBezierPath(rect: bounds)
        scrim.append(NSBezierPath(rect: cropRect))
        scrim.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.55).setFill()
        scrim.fill()

        NSColor.systemOrange.setStroke()
        let border = NSBezierPath(rect: cropRect)
        border.lineWidth = 1.5
        border.stroke()

        NSColor.white.withAlphaComponent(0.22).setStroke()
        let thirds = NSBezierPath()
        for i in 1..<3 {
            let x = cropRect.minX + cropRect.width * CGFloat(i) / 3
            thirds.move(to: NSPoint(x: x, y: cropRect.minY))
            thirds.line(to: NSPoint(x: x, y: cropRect.maxY))
            let y = cropRect.minY + cropRect.height * CGFloat(i) / 3
            thirds.move(to: NSPoint(x: cropRect.minX, y: y))
            thirds.line(to: NSPoint(x: cropRect.maxX, y: y))
        }
        thirds.lineWidth = 0.5
        thirds.stroke()

        for point in cornerPoints() {
            let rect = CGRect(
                x: point.x - handleSize / 2,
                y: point.y - handleSize / 2,
                width: handleSize, height: handleSize
            )
            NSColor.white.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2).fill()
            let path = NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2)
            path.lineWidth = 1
            NSColor.systemOrange.setStroke()
            path.stroke()
        }
    }

    private func cornerPoints() -> [NSPoint] {
        [
            NSPoint(x: cropRect.minX, y: cropRect.maxY), // top-left
            NSPoint(x: cropRect.maxX, y: cropRect.maxY), // top-right
            NSPoint(x: cropRect.maxX, y: cropRect.minY), // bottom-right
            NSPoint(x: cropRect.minX, y: cropRect.minY)  // bottom-left
        ]
    }

    private func hitTest(_ point: NSPoint) -> Handle {
        let handles: [(Handle, NSPoint)] = [
            (.topLeft, NSPoint(x: cropRect.minX, y: cropRect.maxY)),
            (.topRight, NSPoint(x: cropRect.maxX, y: cropRect.maxY)),
            (.bottomRight, NSPoint(x: cropRect.maxX, y: cropRect.minY)),
            (.bottomLeft, NSPoint(x: cropRect.minX, y: cropRect.minY))
        ]
        for (handle, p) in handles where abs(point.x - p.x) <= handleSize &&
            abs(point.y - p.y) <= handleSize {
            return handle
        }
        return cropRect.contains(point) ? .move : .none
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        dragHandle = hitTest(point)
        dragStart = point
        startRect = cropRect
    }

    override func mouseDragged(with event: NSEvent) {
        guard dragHandle != .none, image != nil else { return }
        let point = convert(event.locationInWindow, from: nil)
        let dx = point.x - dragStart.x
        let dy = point.y - dragStart.y
        let b = imageRect
        var rect = startRect

        switch dragHandle {
        case .move:
            rect.origin.x += dx
            rect.origin.y += dy
            rect = clamp(rect)

        case .topLeft:
            rect.origin.x = min(startRect.minX + dx, startRect.maxX - minSize)
            rect.size.height = min(
                max(minSize, startRect.height + dy),
                b.maxY - startRect.minY
            )
            if let aspect {
                let width = rect.height * aspect
                rect.origin.x = startRect.maxX - width
                rect.size.width = width
            } else {
                rect.size.width = startRect.maxX - rect.minX
            }
            rect = clamp(rect)

        case .topRight:
            let width = min(max(minSize, startRect.width + dx), b.maxX - startRect.minX)
            rect.size.width = width
            if let aspect {
                rect.size.height = width / aspect
                rect.origin.y = startRect.maxY - rect.height
            } else {
                rect.size.height = min(max(minSize, startRect.height + dy), b.maxY - startRect.minY)
            }
            rect.origin.x = startRect.minX
            rect = clamp(rect)

        case .bottomRight:
            let width = min(max(minSize, startRect.width + dx), b.maxX - startRect.minX)
            rect.size.width = width
            if let aspect {
                rect.size.height = width / aspect
                rect.origin.y = startRect.minY
            } else {
                rect.origin.y = startRect.minY + dy
                rect.size.height = startRect.maxY - rect.origin.y
            }
            rect.origin.x = startRect.minX
            rect = clamp(rect)

        case .bottomLeft:
            rect.origin.x = min(startRect.minX + dx, startRect.maxX - minSize)
            let width = startRect.maxX - rect.minX
            rect.size.width = width
            if let aspect {
                rect.size.height = width / aspect
                rect.origin.y = startRect.maxY - rect.height
            } else {
                rect.origin.y = startRect.minY + dy
                rect.size.height = startRect.maxY - rect.origin.y
            }
            rect = clamp(rect)

        case .none:
            return
        }

        cropRect = rect
        notify()
    }
}
