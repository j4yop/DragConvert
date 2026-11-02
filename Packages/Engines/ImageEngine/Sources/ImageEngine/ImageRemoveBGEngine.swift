import Foundation
import AppKit
import CoreImage
import Vision
import JobCore
import EngineKit

public struct ImageRemoveBGEngine: Engine {
    public let id = "image.removebg"

    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    public init() {}

    public func canHandle(_ job: Job) -> Bool {
        if case .imageRemoveBG = job.operation { return true }
        return false
    }

    public func run(
        _ job: Job,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> [URL] {
        guard let input = job.inputs.first else {
            throw EngineError.corruptInput("(missing file)")
        }
        guard case .imageRemoveBG = job.operation else {
            throw EngineError.unsupported("\(job.operation)")
        }
        guard let image = ImageConvertEngine.loadImage(at: input) else {
            throw EngineError.corruptInput(input.lastPathComponent)
        }

        let cutout = try Self.removeBackground(from: image)

        let base = input.deletingPathExtension().lastPathComponent
        let directory = input.deletingLastPathComponent()
        let candidate = directory.appendingPathComponent("\(base) No BG.png")
        let output = DestinationPolicy.unique(candidate)

        try writeAtomically(to: output) { tmp in
            try ImageConvertEngine.writeImage(cutout, to: tmp, extension: "png")
        }

        progress(1)
        return [output]
    }

    // MARK: Vision

    static func removeBackground(from image: CGImage) throws -> CGImage {
        guard #available(macOS 14.0, *) else {
            throw EngineError.unsupported("Background removal needs macOS 14 or later")
        }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first,
              !observation.allInstances.isEmpty else {
            throw EngineError.unsupported("No subject found")
        }

        let maskBuffer = try observation.generateScaledMaskForImage(
            forInstances: observation.allInstances,
            from: handler
        )
        let mask = CIImage(cvPixelBuffer: maskBuffer)
        let foreground = CIImage(cgImage: image)

        let scaledMask: CIImage
        if mask.extent.size != foreground.extent.size {
            scaledMask = mask.transformed(by: CGAffineTransform(
                scaleX: foreground.extent.width / max(1, mask.extent.width),
                y: foreground.extent.height / max(1, mask.extent.height)
            ))
        } else {
            scaledMask = mask
        }

        guard let blend = CIFilter(name: "CIBlendWithMask") else {
            throw EngineError.writeFailed("could not create the blend filter")
        }
        blend.setValue(foreground, forKey: kCIInputImageKey)
        blend.setValue(CIImage.empty(), forKey: kCIInputBackgroundImageKey)
        blend.setValue(scaledMask, forKey: kCIInputMaskImageKey)

        guard let output = blend.outputImage,
              let cutout = ciContext.createCGImage(output, from: foreground.extent) else {
            throw EngineError.writeFailed("could not render the cutout")
        }
        return cutout
    }
}
