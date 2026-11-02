import Foundation
import ImageIO
import UniformTypeIdentifiers
import JobCore
import EngineKit

public struct ImageMetadataEngine: Engine {
    public let id = "image.metadata"

    public init() {}

    public func canHandle(_ job: Job) -> Bool {
        if case .metadata = job.operation { return true }
        return false
    }

    public func run(
        _ job: Job,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> [URL] {
        guard let input = job.inputs.first else {
            throw EngineError.corruptInput("(missing file)")
        }
        guard case .metadata(let spec) = job.operation else {
            throw EngineError.unsupported("\(job.operation)")
        }

        // `loadImage` applies the EXIF orientation to the pixels, so the clean
        // copy is upright even after the orientation tag is gone.
        guard let image = ImageConvertEngine.loadImage(at: input) else {
            throw EngineError.corruptInput(input.lastPathComponent)
        }
        guard let uti = ImageConvertEngine.uti(forExtension: spec.format) else {
            throw EngineError.unsupported(".\(spec.format)")
        }

        let base = input.deletingPathExtension().lastPathComponent
        let directory = input.deletingLastPathComponent()
        let candidate = directory.appendingPathComponent("\(base) Clean.\(spec.format)")
        let output = DestinationPolicy.unique(candidate)

        try writeAtomically(to: output) { tmp in
            guard let destination = CGImageDestinationCreateWithURL(
                tmp as CFURL, uti.identifier as CFString, 1, nil
            ) else {
                throw EngineError.writeFailed("could not open \(tmp.lastPathComponent)")
            }
            var properties: [CFString: Any] = [:]
            if uti == .jpeg || uti == .heic {
                properties[kCGImageDestinationLossyCompressionQuality] = 0.95
            }
            CGImageDestinationAddImage(destination, image, properties as CFDictionary)
            guard CGImageDestinationFinalize(destination) else {
                throw EngineError.writeFailed("encoder rejected the image")
            }
        }

        progress(1)
        return [output]
    }
}
