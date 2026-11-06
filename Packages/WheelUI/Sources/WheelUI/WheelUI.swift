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

/// The two wheel materials exposed in Settings.
public enum WheelStyle: String, CaseIterable, Identifiable, Sendable {
    case glass
    case solid

    public var id: String { rawValue }
    public var title: String { self == .glass ? "Glass" : "Solid" }

    public static var current: WheelStyle {
        WheelStyle(rawValue: UserDefaults.standard.string(forKey: "wheelStyle") ?? "") ?? .glass
    }
}

public final class WheelPanel: NSPanel {
    private let glass = NSVisualEffectView()
    private let container = NSView()
    public private(set) var style: WheelStyle = .glass

    public init(width: CGFloat = 300, height: CGFloat = 300) {
        container.frame = NSRect(x: 0, y: 0, width: width, height: height)
        container.wantsLayer = true

        glass.frame = container.bounds
        glass.autoresizingMask = [.width, .height]
        glass.material = .hudWindow
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.appearance = NSAppearance(named: .darkAqua)
        glass.maskImage = Self.ringMask(size: container.bounds.size)
        container.addSubview(glass)

        super.init(
            contentRect: container.bounds,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .screenSaver
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

    public func setStyle(_ style: WheelStyle) {
        self.style = style
        glass.isHidden = style == .solid
        glass.material = .hudWindow
        glass.appearance = NSAppearance(named: .darkAqua)
    }

    public func setGlassProgress(_ progress: CGFloat) {
        guard style == .glass else {
            glass.alphaValue = 0
            return
        }
        let t = min(max(progress, 0), 1)
        glass.alphaValue = max(0, min(1, (t - 0.15) / 0.85))
    }

    private static func ringMask(size: NSSize) -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let outer = NSBezierPath(
                ovalIn: NSRect(
                    x: center.x - 132, y: center.y - 132,
                    width: 264, height: 264
                )
            )
            let inner = NSBezierPath(
                ovalIn: NSRect(
                    x: center.x - 118, y: center.y - 118,
                    width: 236, height: 236
                )
            )
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

    /// Glass or Solid. The renderer uses exactly the same geometry for both.
    public var style: WheelStyle = .glass { didSet { needsDisplay = true } }

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

    /// The dial is a single square overlay: the drag preview floats over its
    /// centre, exactly like the reference.
    private var wheelCenter: NSPoint { NSPoint(x: bounds.midX, y: bounds.midY) }
    private var outerRadius: CGFloat { min(bounds.width / 2 - 32, 118) }
    private var innerRadius: CGFloat { 50 }

    private func wedgeAngles(_ index: Int, count: Int) -> (start: CGFloat, end: CGFloat) {
        let step = 360.0 / CGFloat(count)
        let center = 90.0 - step * CGFloat(index)
        let gap: CGFloat = count > 8 ? 0.7 : 1.35
        return (center - step / 2 + gap, center + step / 2 - gap)
    }

    private func point(radius: CGFloat, angle: CGFloat) -> NSPoint {
        let radians = angle * .pi / 180
        return NSPoint(
            x: wheelCenter.x + cos(radians) * radius,
            y: wheelCenter.y + sin(radians) * radius
        )
    }

    /// A rounded annular sector. The radial edges stay at the petal boundary;
    /// the corner radius is cut inward so the visible gap stays small.
    private func roundedWedgePath(_ index: Int, count: Int) -> NSBezierPath {
        let (a0, a1) = wedgeAngles(index, count: count)
        let outer = outerRadius
        let inner = innerRadius
        let outerCorner = max(4, min(10, (outer - inner) * 0.10))
        let innerCorner = max(3, min(outerCorner, inner * 0.10))

        let dOuter = asin(min(0.9, outerCorner / max(1, outer - outerCorner))) * 180 / .pi
        let dInner = asin(min(0.9, innerCorner / max(1, inner + innerCorner))) * 180 / .pi

        let outerEdgeRadius = (outer - outerCorner) * cos(dOuter * .pi / 180)
        let innerEdgeRadius = (inner + innerCorner) * cos(dInner * .pi / 180)

        let path = NSBezierPath()
        path.move(to: point(radius: outer, angle: a0 + dOuter))
        path.appendArc(
            withCenter: wheelCenter,
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
            withCenter: wheelCenter,
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
        let c = wheelCenter
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
        transform.translateX(by: wheelCenter.x, yBy: wheelCenter.y)
        transform.scale(by: scale)
        transform.translateX(by: -wheelCenter.x, yBy: -wheelCenter.y)
        transform.concat()

        drawBackdrop()
        drawPetals()
        drawCentre()

        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawBackdrop() {
        let center = wheelCenter
        let radius = outerRadius + 14
        let reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        let useGlass = style == .glass && glassEnabled && !reduceTransparency

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.60)
        shadow.shadowBlurRadius = 22
        shadow.shadowOffset = NSSize(width: 0, height: -6)
        shadow.set()

        let backdrop = NSBezierPath(
            ovalIn: NSRect(
                x: center.x - radius, y: center.y - radius,
                width: radius * 2, height: radius * 2
            )
        )
        if useGlass {
            NSColor(white: 0.012, alpha: 0.93).setFill()
            backdrop.fill()
        } else {
            NSGradient(
                starting: NSColor(white: 0.115, alpha: 0.985),
                ending: NSColor(white: 0.045, alpha: 0.995)
            )?.draw(in: backdrop, angle: -90)
        }
        NSGraphicsContext.restoreGraphicsState()

        NSColor.white.withAlphaComponent(useGlass ? 0.065 : 0.075).setStroke()
        backdrop.lineWidth = 1
        backdrop.stroke()

        // Soft specular arc at the top of the glass rim.
        let specular = NSBezierPath()
        specular.appendArc(
            withCenter: center,
            radius: radius - 1.5,
            startAngle: 104,
            endAngle: 168,
            clockwise: false
        )
        NSColor.white.withAlphaComponent(useGlass ? 0.30 : 0.10).setStroke()
        specular.lineWidth = 1.8
        specular.stroke()
    }

    private func drawPetals() {
        let reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        let useGlass = style == .glass && glassEnabled && !reduceTransparency
        let baseGradient: NSGradient?
        if useGlass {
            baseGradient = NSGradient(
                colorsAndLocations:
                    (NSColor(white: 0.205, alpha: 0.94), 0.0),
                    (NSColor(white: 0.105, alpha: 0.95), 0.55),
                    (NSColor(white: 0.065, alpha: 0.96), 1.0)
            )
        } else {
            baseGradient = NSGradient(
                colorsAndLocations:
                    (NSColor(white: 0.19, alpha: 1.0), 0.0),
                    (NSColor(white: 0.155, alpha: 1.0), 0.62),
                    (NSColor(white: 0.125, alpha: 1.0), 1.0)
            )
        }

        for i in items.indices {
            let path = roundedWedgePath(i, count: items.count)
            let level = hoverLevels.indices.contains(i) ? hoverLevels[i] : 0

            baseGradient?.draw(in: path, angle: -90)

            if level > 0.002 {
                if style == .solid {
                    NSColor(white: 0.84, alpha: level).setFill()
                    path.fill()
                    NSColor.white.withAlphaComponent(0.30 * level).setStroke()
                    path.lineWidth = 1
                    path.stroke()
                } else {
                    accent.withAlphaComponent(level).setFill()
                    path.fill()
                    NSColor.white.withAlphaComponent(0.16 * level).setStroke()
                    path.lineWidth = 0.9
                    path.stroke()
                }
            }

            if level < 0.5 {
                NSColor.white.withAlphaComponent(useGlass ? 0.105 : 0.055).setStroke()
                path.lineWidth = 0.8
                path.stroke()
            } else {
                NSColor.black.withAlphaComponent(style == .solid ? 0.16 : 0.0).setStroke()
                path.lineWidth = 0.8
                path.stroke()
            }

            if i == confirmIndex {
                NSColor.white.withAlphaComponent(0.92).setStroke()
                path.lineWidth = 2
                path.stroke()
            }

            let (a0, a1) = wedgeAngles(i, count: items.count)
            let mid = (a0 + a1) / 2 * .pi / 180
            let labelRadius = (innerRadius + outerRadius) / 2
            let p = NSPoint(
                x: wheelCenter.x + cos(mid) * labelRadius,
                y: wheelCenter.y + sin(mid) * labelRadius
            )
            let labelWhite: CGFloat = style == .solid ? (0.95 - 0.83 * level) : 0.94
            draw(
                item: items[i],
                at: p,
                color: NSColor(white: labelWhite, alpha: 0.96),
                compact: items.count > 8
            )
        }
    }

    private func drawCentre() {
        let center = wheelCenter
        let plateSize: CGFloat = 92
        let plateRect = NSRect(
            x: center.x - plateSize / 2,
            y: center.y - plateSize / 2,
            width: plateSize,
            height: plateSize
        )
        let plate = NSBezierPath(
            roundedRect: plateRect,
            xRadius: 20,
            yRadius: 20
        )
        NSColor(white: 0.035, alpha: style == .solid ? 1 : 0.90).setFill()
        plate.fill()
        NSColor.white.withAlphaComponent(0.10).setStroke()
        plate.lineWidth = 1
        plate.stroke()

        let title = hoveredItem?.title ?? preview?.fileSize ?? "DRAG"
        let font = labelFont(size: title.count > 9 ? 9.2 : (title.count > 6 ? 11.2 : 13), weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
            .kern: 0.2
        ]
        let textSize = (title as NSString).size(withAttributes: attributes)
        let capWidth = min(plateSize - 10, max(58, textSize.width + 26))
        let capRect = NSRect(
            x: center.x - capWidth / 2,
            y: center.y - 14,
            width: capWidth,
            height: 28
        )
        let cap = NSBezierPath(roundedRect: capRect, xRadius: 9.5, yRadius: 9.5)

        if style == .solid {
            NSColor(white: 0.015, alpha: 1).setFill()
            cap.fill()
            NSColor.white.withAlphaComponent(0.82).setStroke()
            cap.lineWidth = 1
            cap.stroke()

            // The solid reference shows the neighbouring capsule edges.
            for offset in [-(capWidth / 2 + 9), capWidth / 2 + 3] {
                let peek = NSRect(
                    x: center.x + offset,
                    y: center.y - 10,
                    width: 5,
                    height: 20
                )
                NSColor.white.withAlphaComponent(0.62).setStroke()
                let peekPath = NSBezierPath(roundedRect: peek, xRadius: 3, yRadius: 3)
                peekPath.lineWidth = 1
                peekPath.stroke()
            }
        } else if hoveredIndex == nil {
            NSColor(white: 0.70, alpha: 1).setFill()
            cap.fill()
            NSColor.white.withAlphaComponent(0.20).setStroke()
            cap.lineWidth = 1
            cap.stroke()
        } else {
            NSColor(white: 0.045, alpha: 0.97).setFill()
            cap.fill()
            NSColor.white.withAlphaComponent(0.14).setStroke()
            cap.lineWidth = 1
            cap.stroke()
        }

        var textAttributes = attributes
        if style == .glass && hoveredIndex == nil {
            textAttributes[.foregroundColor] = NSColor(white: 0.08, alpha: 1)
        }
        (title as NSString).draw(
            at: NSPoint(
                x: center.x - textSize.width / 2,
                y: center.y - textSize.height / 2
            ),
            withAttributes: textAttributes
        )
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
        let font = labelFont(size: compact ? 10.2 : 12.5, weight: .semibold)
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
            let cfg = NSImage.SymbolConfiguration(pointSize: compact ? 11 : 13, weight: .semibold)
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

    private let panel = WheelPanel(width: 300, height: 300)
    private var keyMonitor: Any?
    private let wheel: WheelView
    private var isShown = false
    private var appearTimer: Timer?

    public init() {
        wheel = WheelView(frame: NSRect(x: 0, y: 0, width: 300, height: 300))
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
        let style = WheelStyle.current
        wheel.style = style
        panel.setStyle(style)

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

    /// The dial blooms around the drag point. Finder's drag preview floats
    /// over it, so the ring stays where the pointer is.
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

    /// Keyboard activation absorbs Finder's pending mouse-up by putting the
    /// panel directly under the pointer.
    private func moveToAbsorb(_ point: CGPoint) {
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(
            x: point.x - size.width / 2,
            y: point.y - size.height / 2
        ))
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
        moveToAbsorb(NSEvent.mouseLocation)
        onActivate?(item)
    }
}
