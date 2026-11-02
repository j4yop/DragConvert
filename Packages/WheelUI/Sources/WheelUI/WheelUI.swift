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
    public init(size: CGFloat = 420) {
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
    }

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { false }
}

public final class WheelView: NSView {
    public var items: [WheelItem] = [] { didSet { needsDisplay = true } }
    public var preview: WheelPreview? { didSet { needsDisplay = true } }
    public var onDrop: ((WheelItem, [URL]) -> Void)?
    /// Set after a keyboard choice. The panel stays up to absorb Finder's
    /// pending drop, but ignores hover and performs nothing else.
    public var locked = false

    /// 0...1 used for the spring-in. Kept as a property so the draw path is
    /// deterministic and Reduce Motion can show the final state immediately.
    public var appearProgress: CGFloat = 1 { didSet { needsDisplay = true } }

    private var hoveredIndex: Int?

    private var hapticsEnabled: Bool {
        UserDefaults.standard.object(forKey: "hapticsEnabled") == nil
            || UserDefaults.standard.bool(forKey: "hapticsEnabled")
    }
    private let accentTop = NSColor(srgbRed: 1.0, green: 0.60, blue: 0.30, alpha: 1.0)
    private let accentBottom = NSColor(srgbRed: 0.93, green: 0.31, blue: 0.13, alpha: 1.0)
    private let petalTop = NSColor(srgbRed: 1.0, green: 0.975, blue: 0.94, alpha: 0.97)
    private let petalBottom = NSColor(srgbRed: 0.98, green: 0.89, blue: 0.81, alpha: 0.95)

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
        hoveredIndex = index
        needsDisplay = true
    }

    public func moveHighlight(by delta: Int) {
        guard !items.isEmpty else { return }
        let current = hoveredIndex ?? (delta > 0 ? -1 : 0)
        let next = ((current + delta) % items.count + items.count) % items.count
        hoveredIndex = next
        needsDisplay = true
        if hapticsEnabled {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }

    public func updateHover(atScreenPoint point: CGPoint) {
        guard !locked else { return }
        guard let window else { return }
        let inWindow = window.convertPoint(fromScreen: point)
        let inView = convert(inWindow, from: nil)
        let index = index(at: inView)
        if index != hoveredIndex {
            hoveredIndex = index
            needsDisplay = true
            if index != nil, hapticsEnabled {
                NSHapticFeedbackManager.defaultPerformer.perform(
                    .alignment,
                    performanceTime: .now
                )
            }
        }
    }

    // MARK: Drag destination

    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !locked else { return .copy }
        hoveredIndex = index(at: convert(sender.draggingLocation, from: nil))
        needsDisplay = true
        return .copy
    }

    public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !locked else { return .copy }
        hoveredIndex = index(at: convert(sender.draggingLocation, from: nil))
        needsDisplay = true
        return .copy
    }

    public override func draggingExited(_ sender: NSDraggingInfo?) {
        hoveredIndex = nil
        needsDisplay = true
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

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.68)
        shadow.shadowBlurRadius = 18
        shadow.shadowOffset = NSSize(width: 0, height: -4)
        shadow.set()

        let backdrop = NSBezierPath(
            ovalIn: NSRect(
                x: center.x - radius, y: center.y - radius,
                width: radius * 2, height: radius * 2
            )
        )
        NSGradient(
            starting: NSColor(srgbRed: 0.96, green: 0.94, blue: 0.91, alpha: 0.97),
            ending: NSColor(srgbRed: 0.88, green: 0.83, blue: 0.79, alpha: 0.95)
        )?.draw(in: backdrop, angle: -90)
        NSGraphicsContext.restoreGraphicsState()

        NSColor.white.withAlphaComponent(0.42).setStroke()
        backdrop.lineWidth = 1
        backdrop.stroke()

        // A small specular arc keeps the wheel feeling like glass.
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
        for i in items.indices {
            let path = roundedWedgePath(i, count: items.count)
            let hovered = (i == hoveredIndex)
            if hovered {
                NSGradient(starting: accentTop, ending: accentBottom)?.draw(in: path, angle: -90)
            } else {
                NSGradient(starting: petalTop, ending: petalBottom)?.draw(in: path, angle: -90)
            }

            (hovered ? NSColor.white.withAlphaComponent(0.52) : NSColor.white.withAlphaComponent(0.55)).setStroke()
            path.lineWidth = 1
            path.stroke()

            let (a0, a1) = wedgeAngles(i, count: items.count)
            let mid = (a0 + a1) / 2 * .pi / 180
            let labelRadius = (innerRadius + outerRadius) / 2
            let p = NSPoint(
                x: bounds.midX + cos(mid) * labelRadius,
                y: bounds.midY + sin(mid) * labelRadius
            )
            draw(
                item: items[i],
                at: p,
                color: hovered ? .white : NSColor.black.withAlphaComponent(0.82),
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

        NSColor(srgbRed: 0.99, green: 0.91, blue: 0.84, alpha: 0.84).setFill()
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
            drawSymbol("doc.fill", in: thumbRect.insetBy(dx: 18, dy: 18), color: accentBottom)
        }

        NSColor.white.withAlphaComponent(0.62).setStroke()
        let outline = NSBezierPath(roundedRect: thumbRect, xRadius: 16, yRadius: 16)
        outline.lineWidth = 1.4
        outline.stroke()

        let pillText = preview.fileSize
        let pillFont = labelFont(size: 9.5, weight: .semibold)
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

        let nameFont = labelFont(size: 8.5, weight: .medium)
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
        drawSymbol("doc.fill", in: symbol, color: accentBottom)
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
        let font = labelFont(size: compact ? 9 : 10.5, weight: .semibold)
        let text = item.title as NSString
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = text.size(withAttributes: attrs)
        var labelY = p.y - size.height / 2

        if !item.symbol.isEmpty,
           let base = NSImage(systemSymbolName: item.symbol, accessibilityDescription: nil) {
            let cfg = NSImage.SymbolConfiguration(pointSize: compact ? 9 : 12, weight: .medium)
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

    private let panel = WheelPanel()
    private var keyMonitor: Any?
    private let wheel: WheelView
    private var isShown = false
    private var appearTimer: Timer?

    public init() {
        wheel = WheelView(frame: NSRect(x: 0, y: 0, width: 420, height: 420))
        panel.contentView = wheel
        wheel.onDrop = { [weak self] item, urls in
            self?.onDrop?(item, urls)
            self?.hide()
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
            wheel.appearProgress = reduceMotion ? 1 : 0
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            // A non-activating panel can own the keyboard without bringing
            // the app forward, which is how the wheel gets keys mid-drag.
            panel.makeKey()
            isShown = true
            installKeyMonitor()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = reduceMotion ? 0.10 : 0.18
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
        wheel.items = []
        wheel.appearProgress = 1
    }

    private func startAppearAnimation() {
        appearTimer?.invalidate()
        let start = Date()
        let duration: TimeInterval = 0.26
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let t = min(1, Date().timeIntervalSince(start) / duration)
            // ease-out cubic
            let eased = 1 - pow(1 - t, 3)
            self.wheel.appearProgress = CGFloat(0.86 + 0.14 * eased)
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
            onCancel?()
            hide()
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
        // Keep the panel under the pointer so Finder's pending drop is
        // absorbed by it instead of landing on whatever is behind.
        move(to: NSEvent.mouseLocation)
        onActivate?(item)
    }
}
