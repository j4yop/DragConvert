import Foundation
import AppKit
import JobCore
import EngineKit

public struct ImageRedactEngine: Engine {
    public let id = "image.redact"

    public init() {}

    public func canHandle(_ job: Job) -> Bool {
        if case .imageRedact = job.operation { return true }
        return false
    }

    public func run(
        _ job: Job,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> [URL] {
        guard let input = job.inputs.first else {
            throw EngineError.corruptInput("(missing file)")
        }
        guard case .imageRedact(let spec) = job.operation else {
            throw EngineError.unsupported("\(job.operation)")
        }
        guard !spec.redactions.isEmpty else {
            throw EngineError.unsupported("Draw at least one redaction box")
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

        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
        context.setFillColor(NSColor.black.cgColor)
        for redaction in spec.redactions {
            let rect = redaction
            context.fill(CGRect(
                x: rect.x * Double(image.width),
                y: (1 - rect.y - rect.height) * Double(image.height),
                width: rect.width * Double(image.width),
                height: rect.height * Double(image.height)
            ))
        }

        guard let output = context.makeImage() else {
            throw EngineError.writeFailed("could not render the redacted image")
        }

        let base = input.deletingPathExtension().lastPathComponent
        let directory = input.deletingLastPathComponent()
        let candidate = directory.appendingPathComponent("\(base) Redacted.\(spec.format)")
        let destination = DestinationPolicy.unique(candidate)

        try writeAtomically(to: destination) { tmp in
            try ImageConvertEngine.writeImage(
                output, to: tmp, extension: spec.format
            )
        }

        progress(1)
        return [destination]
    }
}
