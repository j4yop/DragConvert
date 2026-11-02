import AppKit
import JobCore

/// Image preview with a draggable crop rectangle.
/// Eight handles, move inside the rect, optional aspect lock.
final class CropCanvas: NSView {
    var image: CGImage? {
        didSet { needsDisplay = true; reset() }
    }

    var aspect: CGFloat? {
        didSet { applyAspect() }
    }

    var onCropChanged: ((CGRect) -> Void)?

    /// Full-resolution pixel size of the source image, when the preview is
    /// downscaled. `nil` means the preview itself is full size.
    var sourceSize: CGSize?

    private(set) var cropRect: CGRect = .zero

    private enum Handle {
        case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left, move, none
    }
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

    /// Crop rect in the preview image's pixels (used by the PDF crop panel).
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

    /// Crop rect in the full-resolution source pixels (image crop engine).
    func sourcePixelRect() -> CGRect {
        guard let image, imageRect.width > 0, imageRect.height > 0 else { return .zero }
        let target = sourceSize ?? CGSize(width: image.width, height: image.height)
        guard target.width > 0, target.height > 0 else { return .zero }
        let sx = target.width / imageRect.width
        let sy = target.height / imageRect.height
        return CGRect(
            x: ((cropRect.minX - imageRect.minX) * sx).rounded(),
            y: ((imageRect.maxY - cropRect.maxY) * sy).rounded(),
            width: (cropRect.width * sx).rounded(),
            height: (cropRect.height * sy).rounded()
        )
    }

    /// Crop rect normalised to 0...1 with a top-left origin, for batch crops.
    func normalizedCrop() -> PDFRect {
        let rect = imageRect
        guard rect.width > 0, rect.height > 0 else {
            return PDFRect(x: 0, y: 0, width: 0, height: 0)
        }
        return PDFRect(
            x: Double((cropRect.minX - rect.minX) / rect.width),
            y: Double((rect.maxY - cropRect.maxY) / rect.height),
            width: Double(cropRect.width / rect.width),
            height: Double(cropRect.height / rect.height)
        )
    }

    /// Apply an exact pixel size, keeping the crop's top-left corner.
    func setCropSize(widthPixels: Int, heightPixels: Int) {
        guard let image, imageRect.width > 0, imageRect.height > 0 else { return }
        let target = sourceSize ?? CGSize(width: image.width, height: image.height)
        guard target.width > 0, target.height > 0 else { return }
        let viewWidth = CGFloat(max(1, widthPixels)) / target.width * imageRect.width
        let viewHeight = CGFloat(max(1, heightPixels)) / target.height * imageRect.height
        var rect = CGRect(
            x: cropRect.minX,
            y: cropRect.maxY - viewHeight,
            width: viewWidth,
            height: viewHeight
        )
        rect = clamp(rect)
        cropRect = rect
        notify()
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

        for (_, point) in handlePoints() {
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

    private func handlePoints() -> [(Handle, NSPoint)] {
        [
            (.topLeft, NSPoint(x: cropRect.minX, y: cropRect.maxY)),
            (.top, NSPoint(x: cropRect.midX, y: cropRect.maxY)),
            (.topRight, NSPoint(x: cropRect.maxX, y: cropRect.maxY)),
            (.right, NSPoint(x: cropRect.maxX, y: cropRect.midY)),
            (.bottomRight, NSPoint(x: cropRect.maxX, y: cropRect.minY)),
            (.bottom, NSPoint(x: cropRect.midX, y: cropRect.minY)),
            (.bottomLeft, NSPoint(x: cropRect.minX, y: cropRect.minY)),
            (.left, NSPoint(x: cropRect.minX, y: cropRect.midY))
        ]
    }

    private func hitTest(_ point: NSPoint) -> Handle {
        for (handle, p) in handlePoints()
        where abs(point.x - p.x) <= handleSize && abs(point.y - p.y) <= handleSize {
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

        case .top:
            rect.size.height = min(
                max(minSize, startRect.height + dy),
                b.maxY - startRect.minY
            )
            rect.origin.y = startRect.minY
            if let aspect {
                let width = min(rect.height * aspect, b.width)
                rect.size.width = width
                rect.origin.x = startRect.midX - width / 2
            } else {
                rect.size.width = startRect.width
            }
            rect = clamp(rect)

        case .bottom:
            rect.origin.y = min(max(b.minY, startRect.minY + dy), startRect.maxY - minSize)
            rect.size.height = startRect.maxY - rect.origin.y
            if let aspect {
                let width = min(rect.height * aspect, b.width)
                rect.size.width = width
                rect.origin.x = startRect.midX - width / 2
            } else {
                rect.size.width = startRect.width
            }
            rect = clamp(rect)

        case .left:
            rect.origin.x = min(max(b.minX, startRect.minX + dx), startRect.maxX - minSize)
            rect.size.width = startRect.maxX - rect.origin.x
            if let aspect {
                let height = min(rect.width / aspect, b.height)
                rect.size.height = height
                rect.origin.y = startRect.midY - height / 2
            } else {
                rect.size.height = startRect.height
            }
            rect = clamp(rect)

        case .right:
            rect.size.width = min(max(minSize, startRect.width + dx), b.maxX - startRect.minX)
            rect.origin.x = startRect.minX
            if let aspect {
                let height = min(rect.width / aspect, b.height)
                rect.size.height = height
                rect.origin.y = startRect.midY - height / 2
            } else {
                rect.size.height = startRect.height
            }
            rect = clamp(rect)

        case .none:
            return
        }

        cropRect = rect
        notify()
    }
}
