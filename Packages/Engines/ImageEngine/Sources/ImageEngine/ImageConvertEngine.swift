import Foundation
import AppKit
import ImageIO
import UniformTypeIdentifiers
import JobCore
import EngineKit

public struct ImageConvertEngine: Engine {
    public let id = "image.convert"

    public init() {}

    public func canHandle(_ job: Job) -> Bool {
        guard case .convert(let ext) = job.operation else { return false }
        // SVG needs a real rasteriser (resvg). Until that ships, do not
        // advertise an SVG conversion that ImageIO cannot perform.
        if job.inputs.contains(where: { $0.pathExtension.lowercased() == "svg" }) {
            return false
        }
        return Self.uti(forExtension: ext) != nil
    }

    public func run(
        _ job: Job,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> [URL] {
        guard let input = job.inputs.first else {
            throw EngineError.corruptInput("(missing file)")
        }
        guard case .convert(let ext) = job.operation else {
            throw EngineError.unsupported("\(job.operation)")
        }
        guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
              let image = Self.loadFullSizeImage(from: source) else {
            throw EngineError.corruptInput(input.lastPathComponent)
        }
        let sourceProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
            as? [CFString: Any]

        let output = DestinationPolicy.outputURL(for: input, extension: ext)
        try writeAtomically(to: output) { tmp in
            if ext.lowercased() == "pdf" {
                try Self.writePDF(image, to: tmp)
            } else {
                try Self.writeImage(
                    image,
                    to: tmp,
                    extension: ext,
                    metadata: ConversionDefaults.preservesMetadata(for: ext)
                        ? sourceProperties
                        : nil
                )
            }
        }
        progress(1)
        return [output]
    }

    public static func loadImage(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return loadFullSizeImage(from: source)
    }

    /// Pixel size after EXIF orientation, without decoding the image.
    public static func imageSize(at url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue
        else { return nil }

        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        if [5, 6, 7, 8].contains(orientation) {
            return CGSize(width: height, height: width)
        }
        return CGSize(width: width, height: height)
    }

    /// Downscaled, orientation-correct preview for editors.
    public static func loadPreview(at url: URL, maxPixel: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    static func loadFullSizeImage(from source: CGImageSource) -> CGImage? {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
        let maxPixel = max(width, height)

        if maxPixel > 0 {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel
            ]
            if let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
                return image
            }
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    static func writeImage(
        _ image: CGImage,
        to url: URL,
        extension ext: String,
        metadata: [CFString: Any]? = nil
    ) throws {
        guard let uti = uti(forExtension: ext),
              let destination = CGImageDestinationCreateWithURL(
                url as CFURL, uti.identifier as CFString, 1, nil
              ) else {
            throw EngineError.writeFailed("could not open \(url.lastPathComponent)")
        }
        var properties: [CFString: Any] = [:]
        if uti == .jpeg {
            properties[kCGImageDestinationLossyCompressionQuality] =
                ConversionDefaults.quality(for: ext, fallback: 0.9)
        } else if uti == .heic {
            properties[kCGImageDestinationLossyCompressionQuality] =
                ConversionDefaults.quality(for: ext, fallback: 0.85)
        } else if uti == UTType(filenameExtension: "avif") {
            properties[kCGImageDestinationLossyCompressionQuality] =
                ConversionDefaults.quality(for: ext, fallback: 0.85)
        }
        if let metadata {
            for key in [
                kCGImagePropertyExifDictionary,
                kCGImagePropertyIPTCDictionary,
                kCGImagePropertyTIFFDictionary,
                kCGImagePropertyGPSDictionary
            ] {
                if let value = metadata[key] {
                    properties[key] = value
                }
            }
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw EngineError.writeFailed("encoder rejected the image")
        }
    }

    static func writePDF(_ image: CGImage, to url: URL) throws {
        var mediaBox = CGRect(
            x: 0, y: 0,
            width: CGFloat(image.width), height: CGFloat(image.height)
        )
        guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
            throw EngineError.writeFailed("could not create a PDF context")
        }
        context.beginPDFPage(nil)
        context.draw(image, in: mediaBox)
        context.endPDFPage()
        context.closePDF()
    }

    static func uti(forExtension ext: String) -> UTType? {
        switch ext.lowercased() {
        case "jpg", "jpeg": return .jpeg
        case "png": return .png
        case "heic", "heif": return .heic
        case "tif", "tiff": return .tiff
        case "bmp": return .bmp
        case "avif": return UTType(filenameExtension: "avif")
        case "pdf": return .pdf
        default: return nil
        }
    }
}
