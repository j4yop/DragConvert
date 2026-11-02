import AppKit
import CapabilityGraph

public final class WheelPanel: NSPanel {
    public init(size: CGFloat = 340) {
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

    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }
}

public final class WheelView: NSView {
    public var items: [WheelItem] = [] { didSet { needsDisplay = true } }
    public var filename: String = "" { didSet { needsDisplay = true } }
    public var onDrop: ((WheelItem, [URL]) -> Void)?

    private var hoveredIndex: Int?
    private let accent = NSColor(srgbRed: 1.0, green: 0.42, blue: 0.18, alpha: 1.0)

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

    private var outerRadius: CGFloat { min(bounds.width, bounds.height) / 2 - 8 }
    private var innerRadius: CGFloat { outerRadius * 0.40 }

    private func wedgeAngles(_ index: Int, count: Int) -> (start: CGFloat, end: CGFloat) {
        let step = 360.0 / CGFloat(count)
        let center = 90.0 - step * CGFloat(index)
        let gap: CGFloat = count > 8 ? 1.8 : 3.0
        return (center - step / 2 + gap / 2, center + step / 2 - gap / 2)
    }

    private func wedgePath(_ index: Int, count: Int) -> NSBezierPath {
        let (a0, a1) = wedgeAngles(index, count: count)
        let c = NSPoint(x: bounds.midX, y: bounds.midY)
        let p = NSBezierPath()
        p.appendArc(withCenter: c, radius: outerRadius, startAngle: a0, endAngle: a1, clockwise: false)
        p.appendArc(withCenter: c, radius: innerRadius, startAngle: a1, endAngle: a0, clockwise: true)
        p.close()
        return p
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
    public func updateHover(atScreenPoint point: CGPoint) {
        guard let window else { return }
        let inWindow = window.convertPoint(fromScreen: point)
        let inView = convert(inWindow, from: nil)
        let index = index(at: inView)
        if index != hoveredIndex {
            hoveredIndex = index
            needsDisplay = true
            if index != nil {
                NSHapticFeedbackManager.defaultPerformer.perform(
                    .alignment,
                    performanceTime: .now
                )
            }
        }
    }

    // MARK: Drag destination

    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        hoveredIndex = index(at: convert(sender.draggingLocation, from: nil))
        needsDisplay = true
        return .copy
    }

    public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        hoveredIndex = index(at: convert(sender.draggingLocation, from: nil))
        needsDisplay = true
        return .copy
    }

    public override func draggingExited(_ sender: NSDraggingInfo?) {
        hoveredIndex = nil
        needsDisplay = true
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
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
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let count = items.count

        NSColor.black.withAlphaComponent(0.12).setFill()
        NSBezierPath(ovalIn: bounds.insetBy(dx: 3, dy: 3)).fill()

        for i in 0..<count {
            let path = wedgePath(i, count: count)
            let hovered = (i == hoveredIndex)
            (hovered ? accent : NSColor.white.withAlphaComponent(0.82)).setFill()
            path.fill()
            (hovered ? NSColor.white.withAlphaComponent(0.5) : NSColor.black.withAlphaComponent(0.07)).setStroke()
            path.lineWidth = 0.8
            path.stroke()

            let (a0, a1) = wedgeAngles(i, count: count)
            let mid = (a0 + a1) / 2 * .pi / 180
            let labelRadius = (innerRadius + outerRadius) / 2
            let p = NSPoint(x: center.x + cos(mid) * labelRadius,
                            y: center.y + sin(mid) * labelRadius)
            let color = hovered ? NSColor.white : NSColor.black.withAlphaComponent(0.82)
            draw(item: items[i], at: p, color: color, compact: count > 8)
        }

        let well = NSRect(x: center.x - innerRadius, y: center.y - innerRadius,
                          width: innerRadius * 2, height: innerRadius * 2)
        NSColor(srgbRed: 0.97, green: 0.64, blue: 0.38, alpha: 0.96).setFill()
        NSBezierPath(ovalIn: well).fill()
        NSColor.white.withAlphaComponent(0.35).setStroke()
        let ring = NSBezierPath(ovalIn: well.insetBy(dx: 1, dy: 1))
        ring.lineWidth = 1
        ring.stroke()

        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byTruncatingMiddle
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8.5, weight: .medium),
            .foregroundColor: NSColor.black.withAlphaComponent(0.8),
            .paragraphStyle: style
        ]
        let maxWidth = innerRadius * 1.7
        let rect = NSRect(x: center.x - maxWidth / 2, y: center.y - 6,
                          width: maxWidth, height: 12)
        (filename as NSString).draw(in: rect, withAttributes: attrs)
    }

    private func draw(item: WheelItem, at p: NSPoint, color: NSColor, compact: Bool) {
        let font = NSFont.systemFont(ofSize: compact ? 8.5 : 10, weight: .semibold)
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

    private let panel = WheelPanel()
    private let wheel: WheelView
    private var isShown = false

    public init() {
        wheel = WheelView(frame: NSRect(x: 0, y: 0, width: 340, height: 340))
        panel.contentView = wheel
        wheel.onDrop = { [weak self] item, urls in
            self?.onDrop?(item, urls)
            self?.hide()
        }
    }

    public var visible: Bool { isShown }
    public var hoveredItem: WheelItem? { isShown ? wheel.hoveredItem : nil }

    /// Shows the wheel, anchored once. It deliberately does **not** follow the
    /// pointer: the pointer has to travel out to a wedge to select it.
    public func show(items: [WheelItem], at point: CGPoint, label: String) {
        guard !items.isEmpty else { hide(); return }
        wheel.items = items
        wheel.filename = label

        if !isShown {
            move(to: point)
            panel.orderFrontRegardless()
            isShown = true
        }
        wheel.needsDisplay = true
    }

    public func updateHover(atScreenPoint point: CGPoint) {
        guard isShown else { return }
        wheel.updateHover(atScreenPoint: point)
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
        panel.orderOut(nil)
        isShown = false
        wheel.items = []
    }
}
