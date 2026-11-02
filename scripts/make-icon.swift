import AppKit
import Foundation

let size: CGFloat = 1024
let canvas = NSRect(x: 0, y: 0, width: size, height: size)

func point(_ radius: CGFloat, _ angle: CGFloat, _ center: CGPoint) -> CGPoint {
    let r = angle * .pi / 180
    return CGPoint(x: center.x + cos(r) * radius, y: center.y + sin(r) * radius)
}

func roundedWedge(index: Int, count: Int, center: CGPoint, outer: CGFloat, inner: CGFloat) -> NSBezierPath {
    let step = 360.0 / CGFloat(count)
    let middle = 90.0 - step * CGFloat(index)
    let gap: CGFloat = 1.15
    let a0 = middle - step / 2 + gap
    let a1 = middle + step / 2 - gap
    let outerCorner = max(10, min(48, (outer - inner) * 0.16))
    let innerCorner = max(8, min(outerCorner, inner * 0.16))
    let dOuter = asin(min(0.9, outerCorner / max(1, outer - outerCorner))) * 180 / .pi
    let dInner = asin(min(0.9, innerCorner / max(1, inner + innerCorner))) * 180 / .pi
    let outerEdge = (outer - outerCorner) * cos(dOuter * .pi / 180)
    let innerEdge = (inner + innerCorner) * cos(dInner * .pi / 180)

    let path = NSBezierPath()
    path.move(to: point(outer, a0 + dOuter, center))
    path.appendArc(withCenter: center, radius: outer, startAngle: a0 + dOuter, endAngle: a1 - dOuter, clockwise: false)
    path.curve(to: point(outerEdge, a1, center), controlPoint1: point(outer, a1, center), controlPoint2: point(outerEdge, a1, center))
    path.line(to: point(innerEdge, a1, center))
    path.curve(to: point(inner, a1 - dInner, center), controlPoint1: point(innerEdge, a1, center), controlPoint2: point(inner, a1, center))
    path.appendArc(withCenter: center, radius: inner, startAngle: a1 - dInner, endAngle: a0 + dInner, clockwise: true)
    path.curve(to: point(innerEdge, a0, center), controlPoint1: point(inner, a0, center), controlPoint2: point(innerEdge, a0, center))
    path.line(to: point(outerEdge, a0, center))
    path.curve(to: point(outer, a0 + dOuter, center), controlPoint1: point(outerEdge, a0, center), controlPoint2: point(outer, a0, center))
    path.close()
    return path
}

let image = NSImage(size: canvas.size)
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { exit(1) }
ctx.setAllowsAntialiasing(true)
ctx.setShouldAntialias(true)

// Warm rounded-square background.
let background = NSBezierPath(roundedRect: canvas.insetBy(dx: 42, dy: 42), xRadius: 214, yRadius: 214)
NSGradient(
    starting: NSColor(srgbRed: 1.0, green: 0.71, blue: 0.40, alpha: 1),
    ending: NSColor(srgbRed: 0.93, green: 0.30, blue: 0.13, alpha: 1)
)?.draw(in: background, angle: -90)

let center = CGPoint(x: 512, y: 512)
let outer: CGFloat = 346
let inner: CGFloat = 142

NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
shadow.shadowBlurRadius = 26
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.set()
NSColor(srgbRed: 0.98, green: 0.93, blue: 0.86, alpha: 0.96).setFill()
NSBezierPath(ovalIn: NSRect(x: center.x - outer - 26, y: center.y - outer - 26, width: (outer + 26) * 2, height: (outer + 26) * 2)).fill()
NSGraphicsContext.restoreGraphicsState()

for index in 0..<8 {
    let path = roundedWedge(index: index, count: 8, center: center, outer: outer, inner: inner)
    NSGradient(
        starting: NSColor(srgbRed: 1.0, green: 0.985, blue: 0.95, alpha: 1),
        ending: NSColor(srgbRed: 0.98, green: 0.89, blue: 0.80, alpha: 1)
    )?.draw(in: path, angle: -90)
    NSColor.white.withAlphaComponent(0.42).setStroke()
    path.lineWidth = 2
    path.stroke()
}

// Dark centre with a white drop arrow.
NSColor(srgbRed: 0.20, green: 0.12, blue: 0.08, alpha: 0.92).setFill()
NSBezierPath(ovalIn: NSRect(x: center.x - inner, y: center.y - inner, width: inner * 2, height: inner * 2)).fill()

NSColor.white.setStroke()
let arrow = NSBezierPath()
arrow.move(to: CGPoint(x: center.x, y: center.y + 54))
arrow.line(to: CGPoint(x: center.x, y: center.y - 28))
arrow.lineWidth = 22
arrow.lineCapStyle = .round
arrow.stroke()

let head = NSBezierPath()
head.move(to: CGPoint(x: center.x - 34, y: center.y + 10))
head.line(to: CGPoint(x: center.x, y: center.y - 30))
head.line(to: CGPoint(x: center.x + 34, y: center.y + 10))
head.lineWidth = 22
head.lineCapStyle = .round
head.lineJoinStyle = .round
head.stroke()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    exit(1)
}
let path = URL(fileURLWithPath: "Config/AppIcon-1024.png")
try png.write(to: path)
print(path.path)
