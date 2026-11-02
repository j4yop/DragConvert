import Foundation
import CoreGraphics
import JobCore
import EngineKit

public struct ImageCropBatchEngine: Engine {
    public let id = "image.crop.batch"

    public init() {}

    public func canHandle(_ job: Job) -> Bool {
        if case .imageCropBatch = job.operation { return true }
        return false
    }

    public func run(
        _ job: Job,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> [URL] {
        guard case .imageCropBatch(let spec) = job.operation else {
            throw EngineError.unsupported("\(job.operation)")
        }
        guard !job.inputs.isEmpty else {
            throw EngineError.corruptInput("(no images)")
        }

        var outputs: [URL] = []
        for (index, input) in job.inputs.enumerated() {
            if Task.isCancelled { throw CancellationError() }
            guard let image = ImageConvertEngine.loadImage(at: input) else {
                throw EngineError.corruptInput(input.lastPathComponent)
            }

            let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
            let rect = CGRect(
                x: spec.normalized.x * Double(image.width),
                y: spec.normalized.y * Double(image.height),
                width: spec.normalized.width * Double(image.width),
                height: spec.normalized.height * Double(image.height)
            ).intersection(bounds)

            guard rect.width >= 1, rect.height >= 1,
                  let cropped = image.cropping(to: rect) else {
                throw EngineError.writeFailed(
                    "the crop area is empty for \(input.lastPathComponent)"
                )
            }

            let ext = ["jpg", "jpeg", "png", "heic", "tiff"]
                .contains(input.pathExtension.lowercased())
                ? input.pathExtension.lowercased()
                : "jpg"
            let base = input.deletingPathExtension().lastPathComponent
            let directory = input.deletingLastPathComponent()
            let candidate = directory.appendingPathComponent("\(base) Cropped.\(ext)")
            let output = DestinationPolicy.unique(candidate)

            try writeAtomically(to: output) { tmp in
                try ImageConvertEngine.writeImage(
                    cropped, to: tmp, extension: ext
                )
            }

            outputs.append(output)
            progress(Double(index + 1) / Double(job.inputs.count))
        }

        return outputs
    }
}
