import Foundation
import AppKit
import ImageIO
import JobCore
import EngineKit

public struct ImageCompressEngine: Engine {
    public let id = "image.compress"

    public init() {}

    public func canHandle(_ job: Job) -> Bool {
        if case .compress = job.operation { return true }
        return false
    }

    public func run(
        _ job: Job,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> [URL] {
        guard let input = job.inputs.first else {
            throw EngineError.corruptInput("(missing file)")
        }
        guard case .compress(let spec) = job.operation else {
            throw EngineError.unsupported("\(job.operation)")
        }
        guard let image = ImageConvertEngine.loadImage(at: input) else {
            throw EngineError.corruptInput(input.lastPathComponent)
        }

        let attributes = try? FileManager.default.attributesOfItem(atPath: input.path)
        let originalBytes = (attributes?[.size] as? NSNumber)?.intValue ?? 0
        let sameFormat = spec.format.lowercased() == input.pathExtension.lowercased()

        let base = input.deletingPathExtension().lastPathComponent
        let directory = input.deletingLastPathComponent()
        let candidate = directory.appendingPathComponent("\(base) Compressed.\(spec.format)")
        let output = DestinationPolicy.unique(candidate)

        // Already smaller than the target: copy, never inflate the file.
        if spec.mode == .targetSize, sameFormat,
           originalBytes > 0, originalBytes <= spec.targetBytes {
            try writeAtomically(to: output) { tmp in
                try FileManager.default.copyItem(at: input, to: tmp)
            }
            progress(1)
            return [output]
        }

        var data: Data
        if spec.mode == .quality {
            guard let encoded = Self.encode(image, format: spec.format, quality: spec.quality) else {
                throw EngineError.writeFailed("encoder rejected the image")
            }
            data = encoded
        } else {
            guard let encoded = Self.compressToTarget(
                image,
                targetBytes: spec.targetBytes,
                format: spec.format,
                allowResize: spec.allowResize
            ) else {
                throw EngineError.writeFailed("could not reach the target size")
            }
            data = encoded
        }

        // Never produce a bigger file than the original when the format is unchanged.
        if sameFormat, originalBytes > 0, data.count >= originalBytes {
            try writeAtomically(to: output) { tmp in
                try FileManager.default.copyItem(at: input, to: tmp)
            }
        } else {
            try writeAtomically(to: output) { tmp in
                try data.write(to: tmp, options: .atomic)
            }
        }

        progress(1)
        return [output]
    }

    // MARK: Encoding

    static func encode(_ image: CGImage, format: String, quality: Double) -> Data? {
        guard let uti = ImageConvertEngine.uti(forExtension: format) else { return nil }
        let buffer = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            buffer as CFMutableData, uti.identifier as CFString, 1, nil
        ) else { return nil }

        var properties: [CFString: Any] = [:]
        if uti == .jpeg || uti == .heic {
            properties[kCGImageDestinationLossyCompressionQuality] = min(max(quality, 0.01), 1.0)
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return buffer as Data
    }

    static func compressToTarget(
        _ image: CGImage,
        targetBytes: Int,
        format: String,
        allowResize: Bool
    ) -> Data? {
        var working = image

        for _ in 0..<6 {
            if let data = searchQuality(working, targetBytes: targetBytes, format: format) {
                return data
            }
            guard allowResize else { break }
            let width = Int(Double(working.width) * 0.85)
            let height = Int(Double(working.height) * 0.85)
            guard width >= 64, height >= 64,
                  let smaller = ImageEditEngine.resize(working, width: width, height: height) else {
                break
            }
            working = smaller
        }

        // Could not reach the target: return the smallest honest attempt.
        return encode(working, format: format, quality: 0.05)
    }

    private static func searchQuality(
        _ image: CGImage,
        targetBytes: Int,
        format: String
    ) -> Data? {
        guard let uti = ImageConvertEngine.uti(forExtension: format) else { return nil }

        if uti == .png {
            guard let data = encode(image, format: format, quality: 1) else { return nil }
            return data.count <= targetBytes ? data : nil
        }

        var low = 0.05
        var high = 0.95
        var best: Data?

        for _ in 0..<8 {
            let mid = (low + high) / 2
            guard let data = encode(image, format: format, quality: mid) else { break }
            if data.count <= targetBytes {
                best = data
                low = mid
            } else {
                high = mid
            }
        }
        return best
    }
}
