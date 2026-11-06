import AppKit
import CapabilityGraph

/// What the wheel shows inside its centre well.
public struct WheelPreview {
    public let image: NSImage?
    public let fileName: String
    public let fileSize: String
    public let isMultiple: Bool

    public init(image: NSImage?, fileName: String, fileSize: String, isMultiple: Bool) {
        self.image = image
        self.fileName = fileName
        self.fileSize = fileSize
        self.isMultiple = isMultiple
    }
}

public final class WheelPanel: NSPanel {
    private let glass = NSVisualEffectView()
    private let container = NSView()

    public init(size: CGFloat = 420) {
        container.frame = NSRect(x: 0, y: 0, width: size, height: size)
        container.wantsLayer = true

        glass.frame = container.bounds
        glass.autoresizingMask = [.width, .height]
        glass.material = .popover
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.appearance = NSAppearance(named: .aqua)
        glass.maskImage = Self.ringMask(size: size)
        container.addSubview(glass)

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: size, height: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        ignoresMouseEvents = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        animationBehavior = .none
        becomesKeyOnlyIfNeeded = true
        contentView = container
    }

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { false }

    public func addWheel(_ view: NSView) {
        view.frame = container.bounds
        view.autoresizingMask = [.width, .height]
        container.addSubview(view)
    }

    public func setGlassProgress(_ progress: CGFloat) {
        let t = min(max(progress, 0), 1)
        glass.alphaValue = max(0, min(1, (t - 0.15) / 0.85))
    }

    private static func ringMask(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let outer = NSBezierPath(ovalIn: rect.insetBy(dx: 14, dy: 14))
            let inner = NSBezierPath(ovalIn: rect.insetBy(dx: 146, dy: 146))
            let ring = NSBezierPath()
            ring.append(outer)
            ring.append(inner)
            ring.windingRule = .evenOdd
            NSColor.white.setFill()
            ring.fill()
            return true
        }
        return image
    }
}

public final class WheelView: NSView {
    public var items: [WheelItem] = [] {
        didSet {
            hoverLevels = Array(repeating: 0, count: items.count)
            needsDisplay = true
        }
    }
    public var preview: WheelPreview? { didSet { needsDisplay = true } }
    public var onDrop: ((WheelItem, [URL]) -> Void)?
    /// Set after a keyboard choice. The panel stays up to absorb Finder's
    /// pending drop, but ignores hover and performs nothing else.
    public var locked = false

    /// 0...1 used for the spring-in. Kept as a property so the draw path is
    /// deterministic and Reduce Motion can show the final state immediately.
    public var appearProgress: CGFloat = 1 { didSet { needsDisplay = true } }

    /// The selected wedge gets a short white confirmation ring while the
    /// wheel fades into the progress HUD.
    public var confirmIndex: Int? { didSet { needsDisplay = true } }

    /// When Reduce Transparency is on, the wheel draws an opaque backdrop
    /// instead of asking the window server for a blur.
    public var glassEnabled: Bool = true

    public private(set) var hoveredIndex: Int?
    private var hoverLevels: [CGFloat] = []
    private var hoverTimer: Timer?

    private let accent = NSColor(srgbRed: 1.0, green: 0.322, blue: 0.0, alpha: 1.0)
    private let accentTop = NSColor(srgbRed: 1.0, green: 0.44, blue: 0.12, alpha: 1.0)

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
        wantsLayer = true
        layer?.backgroundColor = .clear
    }

    public required init?(coder: NSCoder) { fatalError("not used") }

    public var hoveredItem: WheelItem? {
        guard let index = hoveredIndex, index < items.count else { return nil }
        return items[index]
    }

    // MARK: Geometry

    private var outerRadius: CGFloat { min(bounds.width, bounds.height) / 2 - 30 }
    private var innerRadius: CGFloat { outerRadius * 0.405 }

    private func wedgeAngles(_ index: Int, count: Int) -> (start: CGFloat, end: CGFloat) {
        let step = 360.0 / CGFloat(count)
        let center = 90.0 - step * CGFloat(index)
        let gap: CGFloat = count > 8 ? 0.48 : 0.62
        return (center - step / 2 + gap, center + step / 2 - gap)
    }

    private func point(radius: CGFloat, angle: CGFloat) -> NSPoint {
        let radians = angle * .pi / 180
        return NSPoint(
            x: bounds.midX + cos(radians) * radius,
            y: bounds.midY + sin(radians) * radius
        )
    }

    /// A rounded annular sector. The radial edges stay at the petal boundary;
    /// the corner radius is cut inward so the visible gap stays small.
    private func roundedWedgePath(_ index: Int, count: Int) -> NSBezierPath {
        let (a0, a1) = wedgeAngles(index, count: count)
        let outer = outerRadius
        let inner = innerRadius
        let outerCorner = max(4, min(12, (outer - inner) * 0.12))
        let innerCorner = max(3, min(outerCorner, inner * 0.10))

        let dOuter = asin(min(0.9, outerCorner / max(1, outer - outerCorner))) * 180 / .pi
        let dInner = asin(min(0.9, innerCorner / max(1, inner + innerCorner))) * 180 / .pi

        let outerEdgeRadius = (outer - outerCorner) * cos(dOuter * .pi / 180)
        let innerEdgeRadius = (inner + innerCorner) * cos(dInner * .pi / 180)

        let path = NSBezierPath()
        path.move(to: point(radius: outer, angle: a0 + dOuter))
        path.appendArc(
            withCenter: NSPoint(x: bounds.midX, y: bounds.midY),
            radius: outer,
            startAngle: a0 + dOuter,
            endAngle: a1 - dOuter,
            clockwise: false
        )
        path.curve(
            to: point(radius: outerEdgeRadius, angle: a1),
            controlPoint1: point(radius: outer, angle: a1),
            controlPoint2: point(radius: outerEdgeRadius, angle: a1)
        )
        path.line(to: point(radius: innerEdgeRadius, angle: a1))
        path.curve(
            to: point(radius: inner, angle: a1 - dInner),
            controlPoint1: point(radius: innerEdgeRadius, angle: a1),
            controlPoint2: point(radius: inner, angle: a1)
        )
        path.appendArc(
            withCenter: NSPoint(x: bounds.midX, y: bounds.midY),
            radius: inner,
            startAngle: a1 - dInner,
            endAngle: a0 + dInner,
            clockwise: true
        )
        path.curve(
            to: point(radius: innerEdgeRadius, angle: a0),
            controlPoint1: point(radius: inner, angle: a0),
            controlPoint2: point(radius: innerEdgeRadius, angle: a0)
        )
        path.line(to: point(radius: outerEdgeRadius, angle: a0))
        path.curve(
            to: point(radius: outer, angle: a0 + dOuter),
            controlPoint1: point(radius: outerEdgeRadius, angle: a0),
            controlPoint2: point(radius: outer, angle: a0)
        )
        path.close()
        return path
    }

    public func index(at point: NSPoint) -> Int? {
        guard !items.isEmpty else { return nil }
        let c = NSPoint(x: bounds.midX, y: bounds.midY)
        let dx = point.x - c.x, dy = point.y - c.y
        let radius = sqrt(dx * dx + dy * dy)
        guard radius >= innerRadius, radius <= outerRadius else { return nil }
        var angle = atan2(dy, dx) * 180 / .pi
        if angle < 0 { angle += 360 }
        let step = 360.0 / CGFloat(items.count)
        var idx = Int(((90 - angle) / step).rounded())
        idx = ((idx % items.count) + items.count) % items.count
        return idx
    }

    /// Hover driven by the polled pointer, not by drag events. A panel that
    /// appears mid-drag does not reliably receive `draggingUpdated`.
    public func highlight(_ index: Int?) {
        setHover(index, feedback: false)
    }

    public func moveHighlight(by delta: Int) {
        guard !items.isEmpty else { return }
        let current = hoveredIndex ?? (delta > 0 ? -1 : 0)
        let next = ((current + delta) % items.count + items.count) % items.count
        setHover(next, feedback: true)
    }

    public func updateHover(atScreenPoint point: CGPoint) {
        guard !locked else { return }
        guard let window else { return }
        let inWindow = window.convertPoint(fromScreen: point)
        let inView = convert(inWindow, from: nil)
        setHover(index(at: inView), feedback: true)
    }

    private func setHover(_ index: Int?, feedback: Bool) {
        guard index != hoveredIndex else { return }
        hoveredIndex = index
        startHoverAnimation()
        if feedback, index != nil {
            Feedback.shared.hover()
        }
    }

    private func startHoverAnimation() {
        hoverTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            var stillMoving = false
            if self.hoverLevels.count != self.items.count {
                self.hoverLevels = Array(repeating: 0, count: self.items.count)
            }
            for index in self.items.indices {
                let target: CGFloat = index == self.hoveredIndex ? 1 : 0
                let delta = target - self.hoverLevels[index]
                if abs(delta) > 0.004 {
                    self.hoverLevels[index] += delta * 0.22
                    stillMoving = true
                } else {
                    self.hoverLevels[index] = target
                }
            }
            self.needsDisplay = true
            if !stillMoving {
                timer.invalidate()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        hoverTimer = timer
    }

    public func resetInteraction() {
        hoverTimer?.invalidate()
        hoverTimer = nil
        hoveredIndex = nil
        hoverLevels = Array(repeating: 0, count: items.count)
        confirmIndex = nil
        needsDisplay = true
    }

    // MARK: Drag destination

    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !locked else { return .copy }
        setHover(index(at: convert(sender.draggingLocation, from: nil)), feedback: true)
        return .copy
    }

    public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !locked else { return .copy }
        setHover(index(at: convert(sender.draggingLocation, from: nil)), feedback: true)
        return .copy
    }

    public override func draggingExited(_ sender: NSDraggingInfo?) {
        setHover(nil, feedback: false)
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        // A keyboard choice already ran; absorb Finder's pending drop so the
        // file is not also moved or copied somewhere behind the wheel.
        if locked { return true }
        let objects = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) ?? []
        let urls = objects.compactMap { ($0 as? NSURL).map { $0 as URL } }
        guard let idx = index(at: convert(sender.draggingLocation, from: nil)) ?? hoveredIndex,
              idx < items.count, !urls.isEmpty else { return false }
        onDrop?(items[idx], urls)
        return true
    }

    // MARK: Drawing

    public override func draw(_ dirtyRect: NSRect) {
        guard !items.isEmpty else { return }

        NSGraphicsContext.saveGraphicsState()
        let scale = 0.86 + 0.14 * min(max(appearProgress, 0), 1)
        let transform = NSAffineTransform()
        transform.translateX(by: bounds.midX, yBy: bounds.midY)
        transform.scale(by: scale)
        transform.translateX(by: -bounds.midX, yBy: -bounds.midY)
        transform.concat()

        drawBackdrop()
        drawPetals()
        drawCentre()

        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawBackdrop() {
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let radius = outerRadius + 13
        let reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        let useGlass = glassEnabled && !reduceTransparency

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(useGlass ? 0.20 : 0.30)
        shadow.shadowBlurRadius = useGlass ? 16 : 18
        shadow.shadowOffset = NSSize(width: 0, height: -4)
        shadow.set()

        let backdrop = NSBezierPath(
            ovalIn: NSRect(
                x: center.x - radius, y: center.y - radius,
                width: radius * 2, height: radius * 2
            )
        )
        if useGlass {
            NSColor(srgbRed: 1.0, green: 0.96, blue: 0.91, alpha: 0.10).setFill()
            backdrop.fill()
        } else {
            NSGradient(
                starting: NSColor(srgbRed: 0.97, green: 0.94, blue: 0.90, alpha: 0.98),
                ending: NSColor(srgbRed: 0.89, green: 0.84, blue: 0.79, alpha: 0.97)
            )?.draw(in: backdrop, angle: -90)
        }
        NSGraphicsContext.restoreGraphicsState()

        NSColor.white.withAlphaComponent(useGlass ? 0.32 : 0.42).setStroke()
        backdrop.lineWidth = 1
        backdrop.stroke()

        let specular = NSBezierPath()
        specular.appendArc(
            withCenter: center,
            radius: radius - 1,
            startAngle: 102,
            endAngle: 168,
            clockwise: false
        )
        NSColor.white.withAlphaComponent(0.34).setStroke()
        specular.lineWidth = 1.6
        specular.stroke()
    }

    private func drawPetals() {
        let reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        let glassGradient = NSGradient(
            colorsAndLocations:
                (NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.82), 0.0),
                (NSColor(srgbRed: 0.96, green: 0.97, blue: 0.96, alpha: 0.58), 0.68),
                (NSColor(srgbRed: 0.96, green: 0.96, blue: 0.95, alpha: 0.76), 1.0)
        )

        for i in items.indices {
            let path = roundedWedgePath(i, count: items.count)
            let level = hoverLevels.indices.contains(i) ? hoverLevels[i] : 0

            if reduceTransparency {
                NSColor(srgbRed: 1.0, green: 0.97, blue: 0.93, alpha: 0.96).setFill()
                path.fill()
            } else {
                glassGradient?.draw(in: path, relativeCenterPosition: .zero)
            }

            if level > 0.002 {
                accent.withAlphaComponent(level).setFill()
                path.fill()
            }

            let stroke = NSColor(
                srgbRed: 0.36 + 0.40 * level,
                green: 0.40 - 0.15 * level,
                blue: 0.40 - 0.30 * level,
                alpha: 0.20 + 0.24 * level
            )
            stroke.setStroke()
            path.lineWidth = 0.8 + 0.4 * level
            path.stroke()

            if level > 0.01 {
                let (a0, a1) = wedgeAngles(i, count: items.count)
                let ring = NSBezierPath()
                ring.appendArc(
                    withCenter: NSPoint(x: bounds.midX, y: bounds.midY),
                    radius: innerRadius + 1.5,
                    startAngle: a0 + 1.2,
                    endAngle: a1 - 1.2,
                    clockwise: false
                )
                ring.lineWidth = 1.4
                NSColor.white.withAlphaComponent(0.68 * level).setStroke()
                ring.stroke()
            }

            if i == confirmIndex {
                NSColor.white.withAlphaComponent(0.85).setStroke()
                path.lineWidth = 2.1
                path.stroke()
            }

            let (a0, a1) = wedgeAngles(i, count: items.count)
            let mid = (a0 + a1) / 2 * .pi / 180
            let labelRadius = (innerRadius + outerRadius) / 2
            let p = NSPoint(
                x: bounds.midX + cos(mid) * labelRadius,
                y: bounds.midY + sin(mid) * labelRadius
            )
            let brightness = 0.10 + 0.90 * level
            draw(
                item: items[i],
                at: p,
                color: NSColor(calibratedWhite: brightness, alpha: 0.90),
                compact: items.count > 8
            )
        }
    }

    private func drawCentre() {
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let well = NSRect(
            x: center.x - innerRadius, y: center.y - innerRadius,
            width: innerRadius * 2, height: innerRadius * 2
        )

        let reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        NSColor(
            srgbRed: 0.99,
            green: 0.91,
            blue: 0.84,
            alpha: reduceTransparency ? 0.96 : 0.64
        ).setFill()
        NSBezierPath(ovalIn: well).fill()
        NSColor.white.withAlphaComponent(0.36).setStroke()
        let ring = NSBezierPath(ovalIn: well.insetBy(dx: 1, dy: 1))
        ring.lineWidth = 1
        ring.stroke()

        guard let preview else {
            drawPlaceholder(in: well)
            return
        }

        let thumbSize: CGFloat = 68
        let thumbRect = NSRect(
            x: center.x - thumbSize / 2,
            y: center.y - thumbSize / 2 + 8,
            width: thumbSize,
            height: thumbSize
        )

        if preview.isMultiple {
            let behind = thumbRect.offsetBy(dx: -5, dy: 5)
            NSColor.white.withAlphaComponent(0.42).setFill()
            NSBezierPath(roundedRect: behind, xRadius: 16, yRadius: 16).fill()
        }

        if let image = preview.image {
            drawImageFilled(image, in: thumbRect, cornerRadius: 16)
        } else {
            NSColor.white.withAlphaComponent(0.76).setFill()
            NSBezierPath(roundedRect: thumbRect, xRadius: 16, yRadius: 16).fill()
            drawSymbol("doc.fill", in: thumbRect.insetBy(dx: 18, dy: 18), color: accent)
        }

        NSColor.white.withAlphaComponent(0.62).setStroke()
        let outline = NSBezierPath(roundedRect: thumbRect, xRadius: 16, yRadius: 16)
        outline.lineWidth = 1.4
        outline.stroke()

        let pillText = preview.fileSize
        let pillFont = labelFont(size: 10.5, weight: .semibold)
        let pillAttributes: [NSAttributedString.Key: Any] = [
            .font: pillFont,
            .foregroundColor: NSColor.black.withAlphaComponent(0.78)
        ]
        let pillSize = (pillText as NSString).size(withAttributes: pillAttributes)
        let pillRect = NSRect(
            x: center.x - pillSize.width / 2 - 9,
            y: thumbRect.minY - 7,
            width: pillSize.width + 18,
            height: 18
        )
        NSColor.white.withAlphaComponent(0.92).setFill()
        NSBezierPath(roundedRect: pillRect, xRadius: 9, yRadius: 9).fill()
        (pillText as NSString).draw(
            at: NSPoint(x: pillRect.midX - pillSize.width / 2, y: pillRect.midY - pillSize.height / 2),
            withAttributes: pillAttributes
        )

        let nameFont = labelFont(size: 9.5, weight: .medium)
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byTruncatingMiddle
        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: nameFont,
            .foregroundColor: NSColor.black.withAlphaComponent(0.70),
            .paragraphStyle: style
        ]
        let nameRect = NSRect(
            x: center.x - innerRadius * 0.79,
            y: pillRect.minY - 15,
            width: innerRadius * 1.58,
            height: 12
        )
        (preview.fileName as NSString).draw(in: nameRect, withAttributes: nameAttributes)
    }

    private func drawPlaceholder(in well: NSRect) {
        let symbol = NSRect(
            x: well.midX - 20, y: well.midY - 12,
            width: 40, height: 40
        )
        drawSymbol("doc.fill", in: symbol, color: accent)
    }

    private func drawImageFilled(_ image: NSImage, in rect: NSRect, cornerRadius: CGFloat) {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius).addClip()

        let size = image.size
        guard size.width > 0, size.height > 0 else {
            NSGraphicsContext.restoreGraphicsState()
            return
        }
        let scale = max(rect.width / size.width, rect.height / size.height)
        let sourceSize = NSSize(width: rect.width / scale, height: rect.height / scale)
        let source = NSRect(
            x: (size.width - sourceSize.width) / 2,
            y: (size.height - sourceSize.height) / 2,
            width: sourceSize.width,
            height: sourceSize.height
        )
        image.draw(
            in: rect,
            from: source,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawSymbol(_ name: String, in rect: NSRect, color: NSColor) {
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
            return
        }
        let config = NSImage.SymbolConfiguration(pointSize: rect.height, weight: .medium)
        guard let symbol = base.withSymbolConfiguration(config) else { return }
        let tinted = tint(symbol, color: color)
        tinted.draw(in: rect)
    }

    private func draw(item: WheelItem, at p: NSPoint, color: NSColor, compact: Bool) {
        let font = labelFont(size: compact ? 10.5 : 13, weight: .semibold)
        let text = item.title as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .kern: compact ? 0.2 : 0.35
        ]
        let size = text.size(withAttributes: attrs)
        var labelY = p.y - size.height / 2

        if !item.symbol.isEmpty,
           let base = NSImage(systemSymbolName: item.symbol, accessibilityDescription: nil) {
            let cfg = NSImage.SymbolConfiguration(pointSize: compact ? 12 : 15, weight: .semibold)
            if let symbol = base.withSymbolConfiguration(cfg) {
                let tinted = tint(symbol, color: color)
                let s = symbol.size
                tinted.draw(in: NSRect(x: p.x - s.width / 2,
                                       y: p.y + size.height / 2 - 1,
                                       width: s.width, height: s.height))
                labelY -= 4
            }
        }

        text.draw(at: NSPoint(x: p.x - size.width / 2, y: labelY), withAttributes: attrs)
    }

    private func labelFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return NSFont(descriptor: descriptor, size: size) ?? base
    }

    private func tint(_ image: NSImage, color: NSColor) -> NSImage {
        let output = NSImage(size: image.size)
        output.lockFocus()
        color.set()
        NSRect(origin: .zero, size: image.size).fill()
        image.draw(at: .zero, from: .zero, operation: .destinationIn, fraction: 1)
        output.unlockFocus()
        return output
    }
}

@MainActor
public final class WheelController {
    public var onDrop: ((WheelItem, [URL]) -> Void)?
    public var onActivate: ((WheelItem) -> Void)?
    /// Called when Escape dismisses the wheel. The drag can continue and the
    /// caller can avoid reopening until the drag ends.
    public var onCancel: (() -> Void)?
    public var onOpenSettings: (() -> Void)?

    private let panel = WheelPanel()
    private var keyMonitor: Any?
    private let wheel: WheelView
    private var isShown = false
    private var appearTimer: Timer?

    public init() {
        wheel = WheelView(frame: NSRect(x: 0, y: 0, width: 420, height: 420))
        wheel.glassEnabled = !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        panel.addWheel(wheel)
        wheel.onDrop = { [weak self] item, urls in
            guard let self else { return }
            self.wheel.locked = true
            self.wheel.confirmIndex = self.wheel.hoveredIndex
            Feedback.shared.select()
            self.onDrop?(item, urls)
            self.hideAnimated()
        }
    }

    public var visible: Bool { isShown }
    public var hoveredItem: WheelItem? { isShown ? wheel.hoveredItem : nil }
    public var isKeyWindow: Bool { panel.isKeyWindow }
    public var isLocked: Bool { wheel.locked }

    /// Shows the wheel, anchored once. It deliberately does **not** follow the
    /// pointer: the pointer has to travel out to a wedge to select it.
    public func show(items: [WheelItem], at point: CGPoint, preview: WheelPreview) {
        guard !items.isEmpty else { hide(); return }
        wheel.items = items
        wheel.preview = preview
        wheel.locked = false

        if !isShown {
            move(to: point)
            let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            wheel.resetInteraction()
            wheel.appearProgress = reduceMotion ? 1 : 0.45
            panel.setGlassProgress(reduceMotion ? 1 : 0)
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            // A non-activating panel can own the keyboard without bringing
            // the app forward, which is how the wheel gets keys mid-drag.
            panel.makeKey()
            isShown = true
            installKeyMonitor()
            Feedback.shared.open()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = reduceMotion ? 0.10 : 0.16
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
            if !reduceMotion { startAppearAnimation() }
        }
        wheel.needsDisplay = true
    }

    public func updateHover(atScreenPoint point: CGPoint) {
        guard isShown else { return }
        wheel.updateHover(atScreenPoint: point)
    }

    /// QA/hover preview hook; does not change the selection logic.
    public func highlight(_ index: Int?) {
        wheel.highlight(index)
    }

    public func move(to point: CGPoint) {
        let size = panel.frame.size
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        var x = point.x - size.width / 2
        var y = point.y - size.height / 2
        x = min(max(x, visible.minX), visible.maxX - size.width)
        y = min(max(y, visible.minY), visible.maxY - size.height)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    public func hide() {
        guard isShown else { return }
        appearTimer?.invalidate()
        appearTimer = nil
        panel.orderOut(nil)
        panel.alphaValue = 1
        removeKeyMonitor()
        isShown = false
        wheel.locked = false
        wheel.resetInteraction()
        wheel.items = []
        wheel.appearProgress = 1
    }

    private func hideAnimated() {
        guard isShown else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor in
                self?.hide()
            }
        }
    }

    private func startAppearAnimation() {
        appearTimer?.invalidate()
        let start = Date()
        let duration: TimeInterval = 0.20
        let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let t = min(1, Date().timeIntervalSince(start) / duration)
            // cubic-bezier(.18,.82,.24,1), close to ease-out quart
            let eased = 1 - pow(1 - t, 4)
            self.wheel.appearProgress = CGFloat(0.45 + 0.55 * eased)
            self.panel.setGlassProgress(CGFloat(eased))
            if t >= 1 {
                timer.invalidate()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        appearTimer = timer
    }

    // MARK: Keyboard

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isShown, self.panel.isKeyWindow else { return event }
            return self.handleKey(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 53: // Escape
            Feedback.shared.cancel()
            onCancel?()
            hideAnimated()
            return true
        case 43: // comma
            Feedback.shared.select()
            onOpenSettings?()
            hideAnimated()
            return true
        case 36, 76: // Return, keypad Enter
            if let item = wheel.hoveredItem { activate(item) }
            return true
        case 123, 126: // Left, Up
            wheel.moveHighlight(by: -1)
            return true
        case 124, 125: // Right, Down
            wheel.moveHighlight(by: 1)
            return true
        default:
            guard let character = event.charactersIgnoringModifiers?.first,
                  let digit = character.wholeNumberValue,
                  (1...9).contains(digit),
                  digit <= wheel.items.count else { return false }
            wheel.highlight(digit - 1)
            if let item = wheel.hoveredItem { activate(item) }
            return true
        }
    }

    private func activate(_ item: WheelItem) {
        wheel.locked = true
        wheel.confirmIndex = wheel.hoveredIndex
        Feedback.shared.select()
        // Keep the panel under the pointer so Finder's pending drop is
        // absorbed by it instead of landing on whatever is behind.
        move(to: NSEvent.mouseLocation)
        onActivate?(item)
    }
}
