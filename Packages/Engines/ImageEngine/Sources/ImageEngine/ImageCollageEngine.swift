import Foundation
import AppKit
import JobCore
import EngineKit

public struct ImageCollageEngine: Engine {
    public let id = "image.collage"

    public init() {}

    public func canHandle(_ job: Job) -> Bool {
        if case .imageCollage = job.operation { return true }
        return false
    }

    public func run(
        _ job: Job,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> [URL] {
        guard case .imageCollage(let spec) = job.operation else {
            throw EngineError.unsupported("\(job.operation)")
        }
        guard job.inputs.count >= 2 else {
            throw EngineError.unsupported("Select at least two images")
        }
        let images = job.inputs.compactMap { ImageConvertEngine.loadImage(at: $0) }
        guard images.count == job.inputs.count else {
            throw EngineError.corruptInput("one of the images could not be read")
        }
        guard let rendered = Self.render(images: images, spec: spec) else {
            throw EngineError.writeFailed("could not compose the collage")
        }

        let first = job.inputs[0]
        let base = first.deletingPathExtension().lastPathComponent
        let directory = first.deletingLastPathComponent()
        let candidate = directory.appendingPathComponent("\(base) Collage.\(spec.format)")
        let output = DestinationPolicy.unique(candidate)

        try writeAtomically(to: output) { tmp in
            try ImageConvertEngine.writeImage(rendered, to: tmp, extension: spec.format)
        }

        progress(1)
        return [output]
    }

    // MARK: Layout + drawing

    public static func render(images: [CGImage], spec: ImageCollageSpec) -> CGImage? {
        guard !images.isEmpty else { return nil }
        let width = max(200, spec.canvasWidth)
        let spacing = max(0, spec.spacing)
        let count = images.count

        let cells: [CGRect]
        let height: Int

        switch spec.layout {
        case .grid:
            let columns = max(1, min(spec.columns, count))
            let rows = Int(ceil(Double(count) / Double(columns)))
            let cell = max(1, (width - spacing * (columns + 1)) / columns)
            height = rows * cell + spacing * (rows + 1)
            cells = (0..<count).map { index in
                let row = index / columns
                let column = index % columns
                return CGRect(
                    x: spacing + column * (cell + spacing),
                    y: height - spacing - (row + 1) * cell - row * spacing,
                    width: cell,
                    height: cell
                )
            }

        case .row:
            let cell = max(1, (width - spacing * (count + 1)) / count)
            height = cell + spacing * 2
            cells = (0..<count).map { index in
                CGRect(
                    x: spacing + index * (cell + spacing),
                    y: spacing,
                    width: cell,
                    height: cell
                )
            }

        case .column:
            let cellWidth = max(1, width - spacing * 2)
            let cellHeight = max(1, Int(Double(cellWidth) * 0.75))
            height = count * cellHeight + spacing * (count + 1)
            cells = (0..<count).map { index in
                CGRect(
                    x: spacing,
                    y: height - spacing - (index + 1) * cellHeight - index * spacing,
                    width: cellWidth,
                    height: cellHeight
                )
            }

        case .featured:
            if count == 1 {
                let cell = max(1, width - spacing * 2)
                height = cell + spacing * 2
                cells = [CGRect(x: spacing, y: spacing, width: cell, height: cell)]
            } else {
                let leftWidth = max(1, Int(Double(width - spacing * 3) * 0.62))
                let leftHeight = max(1, Int(Double(leftWidth) * 4 / 3))
                height = leftHeight + spacing * 2
                let rightWidth = max(1, width - leftWidth - spacing * 3)
                let rest = count - 1
                let rightCellHeight = max(1, (leftHeight - spacing * (rest + 1)) / rest)
                var layout = [CGRect(
                    x: spacing,
                    y: spacing,
                    width: leftWidth,
                    height: leftHeight
                )]
                for index in 0..<rest {
                    layout.append(CGRect(
                        x: spacing + leftWidth + spacing,
                        y: height - spacing - (index + 1) * rightCellHeight - index * spacing,
                        width: rightWidth,
                        height: rightCellHeight
                    ))
                }
                cells = layout
            }
        }

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.setFillColor(NSColor(
            srgbRed: spec.background.red,
            green: spec.background.green,
            blue: spec.background.blue,
            alpha: spec.background.alpha
        ).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        for (image, cell) in zip(images, cells) {
            let radius = CGFloat(min(max(spec.cornerRadius, 0), Int(cell.width) / 2, Int(cell.height) / 2))
            let path = CGPath(
                roundedRect: cell,
                cornerWidth: radius,
                cornerHeight: radius,
                transform: nil
            )
            context.saveGState()
            context.addPath(path)
            context.clip()
            drawAspectFill(image, in: cell, context: context)
            context.restoreGState()
        }

        return context.makeImage()
    }

    private static func drawAspectFill(
        _ image: CGImage,
        in rect: CGRect,
        context: CGContext
    ) {
        let imageAspect = CGFloat(image.width) / CGFloat(image.height)
        let rectAspect = rect.width / rect.height
        let drawRect: CGRect

        if imageAspect > rectAspect {
            let width = rect.height * imageAspect
            drawRect = CGRect(
                x: rect.midX - width / 2,
                y: rect.minY,
                width: width,
                height: rect.height
            )
        } else {
            let height = rect.width / imageAspect
            drawRect = CGRect(
                x: rect.minX,
                y: rect.midY - height / 2,
                width: rect.width,
                height: height
            )
        }
        context.draw(image, in: drawRect)
    }
}
