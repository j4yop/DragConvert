import Foundation
import CoreImage
import JobCore
import EngineKit

public struct ImageAdjustEngine: Engine {
    public let id = "image.adjust"

    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    public init() {}

    public func canHandle(_ job: Job) -> Bool {
        if case .imageAdjust = job.operation { return true }
        return false
    }

    public func run(
        _ job: Job,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> [URL] {
        guard let input = job.inputs.first else {
            throw EngineError.corruptInput("(missing file)")
        }
        guard case .imageAdjust(let spec) = job.operation else {
            throw EngineError.unsupported("\(job.operation)")
        }
        guard let image = ImageConvertEngine.loadImage(at: input) else {
            throw EngineError.corruptInput(input.lastPathComponent)
        }
        guard let output = Self.render(image, spec: spec) else {
            throw EngineError.writeFailed("could not apply the adjustments")
        }

        let base = input.deletingPathExtension().lastPathComponent
        let directory = input.deletingLastPathComponent()
        let candidate = directory.appendingPathComponent("\(base) Edited.\(spec.format)")
        let destination = DestinationPolicy.unique(candidate)

        try writeAtomically(to: destination) { tmp in
            try ImageConvertEngine.writeImage(output, to: tmp, extension: spec.format)
        }

        progress(1)
        return [destination]
    }

    public static func render(_ image: CGImage, spec: ImageAdjustSpec) -> CGImage? {
        let brightness = min(max(spec.brightness, -0.5), 0.5)
        let contrast = min(max(spec.contrast, -0.9), 0.9)
        let saturation = min(max(spec.saturation, -1), 1)
        let warmth = min(max(spec.warmth, -1), 1)

        var output = CIImage(cgImage: image)

        if brightness != 0 || contrast != 0 || saturation != 0 {
            guard let filter = CIFilter(name: "CIColorControls") else { return nil }
            filter.setValue(output, forKey: kCIInputImageKey)
            filter.setValue(brightness, forKey: kCIInputBrightnessKey)
            filter.setValue(1 + contrast, forKey: kCIInputContrastKey)
            filter.setValue(1 + saturation, forKey: kCIInputSaturationKey)
            output = filter.outputImage ?? output
        }

        if warmth != 0 {
            guard let filter = CIFilter(name: "CITemperatureAndTint") else { return nil }
            filter.setValue(output, forKey: kCIInputImageKey)
            filter.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
            filter.setValue(
                CIVector(x: 6500 + warmth * 2000, y: 0),
                forKey: "inputTargetNeutral"
            )
            output = filter.outputImage ?? output
        }

        return ciContext.createCGImage(
            output,
            from: CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
    }
}
