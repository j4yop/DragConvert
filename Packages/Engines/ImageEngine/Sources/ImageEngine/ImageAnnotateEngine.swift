import Foundation
import AppKit
import JobCore
import EngineKit

public struct ImageAnnotateEngine: Engine {
    public let id = "image.annotate"

    public init() {}

    public func canHandle(_ job: Job) -> Bool {
        if case .imageAnnotate = job.operation { return true }
        return false
    }

    public func run(
        _ job: Job,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> [URL] {
        guard let input = job.inputs.first else {
            throw EngineError.corruptInput("(missing file)")
        }
        guard case .imageAnnotate(let spec) = job.operation else {
            throw EngineError.unsupported("\(job.operation)")
        }
        guard !spec.annotations.isEmpty else {
            throw EngineError.unsupported("Add at least one annotation")
        }
        guard let image = ImageConvertEngine.loadImage(at: input) else {
            throw EngineError.corruptInput(input.lastPathComponent)
        }

        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw EngineError.writeFailed("could not create a bitmap context")
        }

        let size = CGSize(width: image.width, height: image.height)
        context.draw(image, in: CGRect(origin: .zero, size: size))
        for annotation in spec.annotations {
            draw(annotation, in: context, size: size)
        }

        guard let output = context.makeImage() else {
            throw EngineError.writeFailed("could not render the annotated image")
        }

        let base = input.deletingPathExtension().lastPathComponent
        let directory = input.deletingLastPathComponent()
        let candidate = directory.appendingPathComponent("\(base) Annotated.\(spec.format)")
        let destination = DestinationPolicy.unique(candidate)

        try writeAtomically(to: destination) { tmp in
            try ImageConvertEngine.writeImage(
                output, to: tmp, extension: spec.format
            )
        }

        progress(1)
        return [destination]
    }

    // MARK: Drawing

    private func draw(_ annotation: PDFAnnotationSpec, in context: CGContext, size: CGSize) {
        let color = NSColor(
            srgbRed: annotation.color.red,
            green: annotation.color.green,
            blue: annotation.color.blue,
            alpha: annotation.color.alpha
        )
        let rect = pixelRect(annotation.rect, in: size)
        let lineWidth = max(2, min(size.width, size.height) / 500)

        switch annotation.kind {
        case .rectangle:
            context.setFillColor(color.withAlphaComponent(0.12).cgColor)
            context.fill(rect)
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(lineWidth)
            context.stroke(rect)

        case .ellipse:
            context.setFillColor(color.withAlphaComponent(0.12).cgColor)
            context.fillEllipse(in: rect)
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(lineWidth)
            context.strokeEllipse(in: rect)

        case .arrow:
            guard annotation.points.count >= 2 else { return }
            let start = pixelPoint(annotation.points[0], in: size)
            let end = pixelPoint(annotation.points[1], in: size)
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(lineWidth)
            context.setLineCap(.round)
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()

            let angle = atan2(end.y - start.y, end.x - start.x)
            let head = max(10, min(size.width, size.height) / 100)
            for offset in [CGFloat.pi * 0.82, -CGFloat.pi * 0.82] {
                let point = CGPoint(
                    x: end.x + cos(angle + offset) * head,
                    y: end.y + sin(angle + offset) * head
                )
                context.move(to: end)
                context.addLine(to: point)
                context.strokePath()
            }

        case .ink:
            guard annotation.points.count > 1 else { return }
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(lineWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.beginPath()
            context.move(to: pixelPoint(annotation.points[0], in: size))
            for point in annotation.points.dropFirst() {
                context.addLine(to: pixelPoint(point, in: size))
            }
            context.strokePath()

        case .text:
            let fontSize = max(12, min(size.width, size.height) / 83)
            let graphics = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = graphics
            ((annotation.text ?? "Note") as NSString).draw(
                in: CGRect(
                    x: rect.minX + 2,
                    y: rect.maxY - fontSize - 4,
                    width: max(20, rect.width - 4),
                    height: fontSize * 2
                ),
                withAttributes: [
                    .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
                    .foregroundColor: color
                ]
            )
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    private func pixelRect(_ rect: PDFRect, in size: CGSize) -> CGRect {
        CGRect(
            x: rect.x * size.width,
            y: (1 - rect.y - rect.height) * size.height,
            width: rect.width * size.width,
            height: rect.height * size.height
        )
    }

    private func pixelPoint(_ point: PDFPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: point.x * size.width,
            y: (1 - point.y) * size.height
        )
    }
}
