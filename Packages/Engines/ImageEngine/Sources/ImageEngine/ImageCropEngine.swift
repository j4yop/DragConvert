import Foundation
import AppKit
import ImageIO
import JobCore
import EngineKit

public struct ImageCropEngine: Engine {
    public let id = "image.crop"

    public init() {}

    public func canHandle(_ job: Job) -> Bool {
        if case .crop = job.operation { return true }
        return false
    }

    public func run(
        _ job: Job,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> [URL] {
        guard let input = job.inputs.first else {
            throw EngineError.corruptInput("(missing file)")
        }
        guard case .crop(let spec) = job.operation else {
            throw EngineError.unsupported("\(job.operation)")
        }
        guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
              let image = ImageConvertEngine.loadFullSizeImage(from: source) else {
            throw EngineError.corruptInput(input.lastPathComponent)
        }

        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let rect = CGRect(
            x: spec.x, y: spec.y,
            width: spec.width, height: spec.height
        ).intersection(bounds)

        guard rect.width >= 1, rect.height >= 1,
              let cropped = image.cropping(to: rect) else {
            throw EngineError.writeFailed("the crop area is empty")
        }

        let base = input.deletingPathExtension().lastPathComponent
        let directory = input.deletingLastPathComponent()
        let candidate = directory.appendingPathComponent("\(base) Cropped.\(spec.format)")
        let output = DestinationPolicy.unique(candidate)

        try writeAtomically(to: output) { tmp in
            try ImageConvertEngine.writeImage(cropped, to: tmp, extension: spec.format)
        }
        progress(1)
        return [output]
    }
}
