import AppKit
import JobCore

final class AnnotateCanvas: NSView {
    var image: CGImage? {
        didSet { needsDisplay = true }
    }

    var annotations: [PDFAnnotationSpec] = [] {
        didSet { needsDisplay = true }
    }

    var tool: PDFAnnotationSpec.Kind = .rectangle
    var color: NSColor = .systemRed
    var noteText: String = ""
    var pageIndex: Int = 0

    var onAdd: ((PDFAnnotationSpec) -> Void)?

    private var dragStart: CGPoint?
    private var draftRect: CGRect?
    private var draftPoints: [CGPoint] = []

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

    // MARK: Coordinate conversion (normalised top-left ↔ view)

    private func normalised(_ point: CGPoint) -> PDFPoint {
        let rect = imageRect
        guard rect.width > 0, rect.height > 0 else { return PDFPoint(x: 0, y: 0) }
        return PDFPoint(
            x: Double((point.x - rect.minX) / rect.width),
            y: Double((rect.maxY - point.y) / rect.height)
        )
    }

    private func viewPoint(_ point: PDFPoint) -> CGPoint {
        let rect = imageRect
        return CGPoint(
            x: rect.minX + CGFloat(point.x) * rect.width,
            y: rect.maxY - CGFloat(point.y) * rect.height
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

    private func normalisedRect(from start: CGPoint, to end: CGPoint) -> PDFRect {
        let a = normalised(start)
        let b = normalised(end)
        return PDFRect(
            x: min(a.x, b.x),
            y: min(a.y, b.y),
            width: abs(b.x - a.x),
            height: abs(b.y - a.y)
        )
    }

    private func annotationColor(_ color: PDFColor) -> NSColor {
        NSColor(
            srgbRed: color.red,
            green: color.green,
            blue: color.blue,
            alpha: color.alpha
        )
    }

    private func pdfColor(_ color: NSColor) -> PDFColor {
        let converted = color.usingColorSpace(.sRGB) ?? .systemRed
        return PDFColor(
            red: Double(converted.redComponent),
            green: Double(converted.greenComponent),
            blue: Double(converted.blueComponent),
            alpha: Double(converted.alphaComponent)
        )
    }

    // MARK: Mouse

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard imageRect.contains(point) else { return }

        if tool == .text {
            var origin = normalised(point)
            origin.x = min(max(origin.x, 0), 0.72)
            origin.y = min(max(origin.y, 0), 0.9)
            let spec = PDFAnnotationSpec(
                kind: .text,
                pageIndex: pageIndex,
                rect: PDFRect(x: origin.x, y: origin.y, width: 0.26, height: 0.08),
                text: noteText.isEmpty ? "Note" : noteText,
                color: pdfColor(color),
                lineWidth: 2
            )
            onAdd?(spec)
            return
        }

        dragStart = point
        draftRect = CGRect(origin: point, size: .zero)
        draftPoints = [point]
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        let point = convert(event.locationInWindow, from: nil)

        switch tool {
        case .arrow, .ink:
            draftPoints.append(point)
            draftRect = nil
        case .rectangle, .ellipse:
            draftRect = CGRect(
                x: min(start.x, point.x),
                y: min(start.y, point.y),
                width: abs(point.x - start.x),
                height: abs(point.y - start.y)
            )
        case .text:
            break
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            dragStart = nil
            draftRect = nil
            draftPoints = []
            needsDisplay = true
        }
        guard let start = dragStart else { return }
        let end = convert(event.locationInWindow, from: nil)

        switch tool {
        case .rectangle, .ellipse:
            let rect = normalisedRect(from: start, to: end)
            guard rect.width > 0.005, rect.height > 0.005 else { return }
            onAdd?(PDFAnnotationSpec(
                kind: tool,
                pageIndex: pageIndex,
                rect: rect,
                color: pdfColor(color),
                lineWidth: 2
            ))

        case .arrow:
            let points = [normalised(start), normalised(end)]
            guard abs(points[0].x - points[1].x) + abs(points[0].y - points[1].y) > 0.01 else { return }
            onAdd?(PDFAnnotationSpec(
                kind: .arrow,
                pageIndex: pageIndex,
                points: points,
                color: pdfColor(color),
                lineWidth: 2
            ))

        case .ink:
            let points = draftPoints.map(normalised)
            guard points.count > 2 else { return }
            onAdd?(PDFAnnotationSpec(
                kind: .ink,
                pageIndex: pageIndex,
                points: points,
                color: pdfColor(color),
                lineWidth: 2
            ))

        case .text:
            break
        }
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        bounds.fill()

        guard let image else { return }
        NSGraphicsContext.current?.cgContext.draw(image, in: imageRect)

        for spec in annotations {
            draw(spec)
        }

        if let rect = draftRect {
            NSColor.systemOrange.setStroke()
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 1.5
            path.stroke()
        }

        if tool == .ink, draftPoints.count > 1 {
            NSColor.systemOrange.setStroke()
            let path = NSBezierPath()
            path.move(to: draftPoints[0])
            for point in draftPoints.dropFirst() { path.line(to: point) }
            path.lineWidth = 2
            path.lineCapStyle = .round
            path.stroke()
        }

        if tool == .arrow, let start = dragStart, let end = draftPoints.last, draftPoints.count > 1 {
            NSColor.systemOrange.setStroke()
            let path = NSBezierPath()
            path.move(to: start)
            path.line(to: end)
            path.lineWidth = 1.5
            path.stroke()
        }
    }

    private func draw(_ spec: PDFAnnotationSpec) {
        let color = annotationColor(spec.color)
        color.setStroke()
        color.withAlphaComponent(0.12).setFill()

        switch spec.kind {
        case .rectangle:
            let path = NSBezierPath(rect: viewRect(spec.rect))
            path.lineWidth = 2
            path.fill()
            path.stroke()

        case .ellipse:
            let path = NSBezierPath(ovalIn: viewRect(spec.rect))
            path.lineWidth = 2
            path.fill()
            path.stroke()

        case .arrow:
            guard spec.points.count >= 2 else { return }
            let start = viewPoint(spec.points[0])
            let end = viewPoint(spec.points[1])
            let path = NSBezierPath()
            path.move(to: start)
            path.line(to: end)
            path.lineWidth = 2
            path.lineCapStyle = .round
            path.stroke()

            let angle = atan2(end.y - start.y, end.x - start.x)
            let length: CGFloat = 12
            for offset in [CGFloat.pi * 0.82, -CGFloat.pi * 0.82] {
                let point = CGPoint(
                    x: end.x + cos(angle + offset) * length,
                    y: end.y + sin(angle + offset) * length
                )
                let head = NSBezierPath()
                head.move(to: end)
                head.line(to: point)
                head.lineWidth = 2
                head.lineCapStyle = .round
                head.stroke()
            }

        case .ink:
            guard spec.points.count > 1 else { return }
            let path = NSBezierPath()
            path.move(to: viewPoint(spec.points[0]))
            for point in spec.points.dropFirst() {
                path.line(to: viewPoint(point))
            }
            path.lineWidth = 2
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()

        case .text:
            let rect = viewRect(spec.rect)
            let text = (spec.text ?? "Note") as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: color
            ]
            text.draw(
                in: CGRect(
                    x: rect.minX + 2,
                    y: rect.maxY - 18,
                    width: max(20, rect.width - 4),
                    height: max(16, rect.height)
                ),
                withAttributes: attributes
            )
        }
    }
}
