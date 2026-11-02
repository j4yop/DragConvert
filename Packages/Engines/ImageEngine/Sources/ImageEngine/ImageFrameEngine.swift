import Foundation
import AppKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import JobCore
import EngineKit

public struct ImageFrameEngine: Engine {
    public let id = "image.frame"

    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    public init() {}

    public func canHandle(_ job: Job) -> Bool {
        if case .imageFrame = job.operation { return true }
        return false
    }

    public func run(
        _ job: Job,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> [URL] {
        guard let input = job.inputs.first else {
            throw EngineError.corruptInput("(missing file)")
        }
        guard case .imageFrame(let spec) = job.operation else {
            throw EngineError.unsupported("\(job.operation)")
        }
        guard let foreground = ImageConvertEngine.loadImage(at: input) else {
            throw EngineError.corruptInput(input.lastPathComponent)
        }

        var background: CGImage?
        if case .image(let url) = spec.background {
            guard let loaded = ImageConvertEngine.loadImage(at: url) else {
                throw EngineError.corruptInput(url.lastPathComponent)
            }
            background = loaded
        }

        guard let rendered = Self.render(
            foreground: foreground,
            background: background,
            spec: spec
        ) else {
            throw EngineError.writeFailed("could not compose the frame")
        }

        let base = input.deletingPathExtension().lastPathComponent
        let directory = input.deletingLastPathComponent()
        let candidate = directory.appendingPathComponent("\(base) Framed.\(spec.format)")
        let output = DestinationPolicy.unique(candidate)

        try writeAtomically(to: output) { tmp in
            guard let uti = ImageConvertEngine.uti(forExtension: spec.format),
                  let destination = CGImageDestinationCreateWithURL(
                    tmp as CFURL, uti.identifier as CFString, 1, nil
                  ) else {
                throw EngineError.writeFailed("could not open \(tmp.lastPathComponent)")
            }
            var properties: [CFString: Any] = [:]
            if uti == .jpeg {
                properties[kCGImageDestinationLossyCompressionQuality] = 0.95
            }
            CGImageDestinationAddImage(destination, rendered, properties as CFDictionary)
            guard CGImageDestinationFinalize(destination) else {
                throw EngineError.writeFailed("encoder rejected the frame")
            }
        }

        progress(1)
        return [output]
    }

    // MARK: Composition (also used by the live preview)

    public static func render(
        foreground: CGImage,
        background: CGImage?,
        spec: ImageFrameSpec
    ) -> CGImage? {
        let paddingPercent = min(max(spec.paddingPercent, 0), 0.4)
        let padding = Int(Double(min(foreground.width, foreground.height)) * paddingPercent)
        let canvasWidth = max(1, foreground.width + padding * 2)
        let canvasHeight = max(1, foreground.height + padding * 2)

        guard let context = CGContext(
            data: nil,
            width: canvasWidth,
            height: canvasHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let canvas = CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight)

        switch spec.background {
        case .color(let color):
            context.setFillColor(NSColor(
                srgbRed: color.red,
                green: color.green,
                blue: color.blue,
                alpha: color.alpha
            ).cgColor)
            context.fill(canvas)

        case .image:
            if let background {
                let image = spec.blurBackground
                    ? (blurred(background) ?? background)
                    : background
                drawAspectFill(image, in: canvas, context: context)
            } else {
                context.setFillColor(NSColor.darkGray.cgColor)
                context.fill(canvas)
            }
        }

        let foregroundRect = CGRect(
            x: padding,
            y: padding,
            width: foreground.width,
            height: foreground.height
        )
        let radius = CGFloat(min(max(spec.cornerRadius, 0), min(canvasWidth, canvasHeight) / 2))
        let path = CGPath(
            roundedRect: foregroundRect,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )

        if spec.shadow {
            context.saveGState()
            context.setShadow(
                offset: CGSize(width: 0, height: -CGFloat(max(4, padding / 4))),
                blur: CGFloat(max(8, padding / 2)),
                color: NSColor.black.withAlphaComponent(0.35).cgColor
            )
            context.setFillColor(NSColor.white.cgColor)
            context.addPath(path)
            context.fillPath()
            context.restoreGState()
        }

        context.saveGState()
        context.addPath(path)
        context.clip()
        context.draw(foreground, in: foregroundRect)
        context.restoreGState()

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

    private static func blurred(_ image: CGImage) -> CGImage? {
        let input = CIImage(cgImage: image)
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return nil }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(
            max(8, min(CGFloat(image.width), CGFloat(image.height)) * 0.03),
            forKey: kCIInputRadiusKey
        )
        guard let output = filter.outputImage else { return nil }
        return ciContext.createCGImage(output, from: input.extent)
    }
}
