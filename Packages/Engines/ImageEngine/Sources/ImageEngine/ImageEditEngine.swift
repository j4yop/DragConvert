import Foundation
import AppKit
import ImageIO
import JobCore
import EngineKit

public struct ImageEditEngine: Engine {
    public let id = "image.edit"

    public init() {}

    public func canHandle(_ job: Job) -> Bool {
        if case .edit = job.operation { return true }
        return false
    }

    public func run(
        _ job: Job,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> [URL] {
        guard let input = job.inputs.first else {
            throw EngineError.corruptInput("(missing file)")
        }
        guard case .edit(let spec) = job.operation else {
            throw EngineError.unsupported("\(job.operation)")
        }
        guard let original = ImageConvertEngine.loadImage(at: input) else {
            throw EngineError.corruptInput(input.lastPathComponent)
        }

        var image = original
        if spec.quarterTurns % 4 != 0 || spec.flipHorizontal || spec.flipVertical {
            guard let rendered = Self.render(
                original,
                quarterTurns: spec.quarterTurns,
                flipHorizontal: spec.flipHorizontal,
                flipVertical: spec.flipVertical
            ) else {
                throw EngineError.writeFailed("could not rotate the image")
            }
            image = rendered
        }

        if spec.width != image.width || spec.height != image.height {
            guard let resized = Self.resize(image, width: spec.width, height: spec.height) else {
                throw EngineError.writeFailed("could not resize the image")
            }
            image = resized
        }

        let base = input.deletingPathExtension().lastPathComponent
        let directory = input.deletingLastPathComponent()
        let candidate = directory.appendingPathComponent("\(base) \(spec.suffix).\(spec.format)")
        let output = DestinationPolicy.unique(candidate)

        try writeAtomically(to: output) { tmp in
            try ImageConvertEngine.writeImage(image, to: tmp, extension: spec.format)
        }
        progress(1)
        return [output]
    }

    // MARK: Pure helpers (also used by the live preview)

    public static func render(
        _ image: CGImage,
        quarterTurns: Int,
        flipHorizontal: Bool,
        flipVertical: Bool
    ) -> CGImage? {
        let turns = ((quarterTurns % 4) + 4) % 4
        if turns == 0 && !flipHorizontal && !flipVertical { return image }

        let width = image.width
        let height = image.height
        let outWidth = turns % 2 == 0 ? width : height
        let outHeight = turns % 2 == 0 ? height : width

        guard let context = CGContext(
            data: nil,
            width: outWidth,
            height: outHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .high
        context.translateBy(x: CGFloat(outWidth) / 2, y: CGFloat(outHeight) / 2)
        context.rotate(by: CGFloat(turns) * .pi / 2)
        if flipHorizontal { context.scaleBy(x: -1, y: 1) }
        if flipVertical { context.scaleBy(x: 1, y: -1) }
        context.translateBy(x: -CGFloat(width) / 2, y: -CGFloat(height) / 2)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    public static func resize(
        _ image: CGImage,
        width: Int,
        height: Int
    ) -> CGImage? {
        guard width > 0, height > 0 else { return nil }
        if width == image.width && height == image.height { return image }

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
