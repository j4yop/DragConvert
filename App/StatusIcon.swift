import AppKit

enum StatusIcon {
    /// A tiny template wheel. Template images are tinted by macOS in both
    /// appearances and stay legible in the menu bar.
    static func make() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let outer: CGFloat = 7.2
            let inner: CGFloat = 2.6

            NSColor.black.setStroke()
            let ring = NSBezierPath(
                ovalIn: NSRect(
                    x: center.x - outer, y: center.y - outer,
                    width: outer * 2, height: outer * 2
                )
            )
            ring.lineWidth = 1.25
            ring.stroke()

            for index in 0..<8 {
                let angle = CGFloat(index) * .pi / 4
                let path = NSBezierPath()
                path.move(to: NSPoint(
                    x: center.x + cos(angle) * inner,
                    y: center.y + sin(angle) * inner
                ))
                path.line(to: NSPoint(
                    x: center.x + cos(angle) * (outer - 1.1),
                    y: center.y + sin(angle) * (outer - 1.1)
                ))
                path.lineWidth = 1.15
                path.lineCapStyle = .round
                path.stroke()
            }

            NSColor.black.setFill()
            NSBezierPath(
                ovalIn: NSRect(
                    x: center.x - 1.8, y: center.y - 1.8,
                    width: 3.6, height: 3.6
                )
            ).fill()
            return true
        }
        image.isTemplate = true
        return image
    }

    static func apply(to button: NSStatusBarButton?) {
        button?.image = make()
        button?.imagePosition = .imageOnly
        button?.title = ""
    }

    static func setBusy(_ busy: Bool, on button: NSStatusBarButton?) {
        button?.contentTintColor = busy ? .systemOrange : nil
    }
}
