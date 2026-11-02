import Foundation
import AppKit
import PDFKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import JobCore
import EngineKit
import ImageEngine

public struct PDFFrameEngine: Engine {
    public let id = "pdf.frame"

    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    public init() {}

    public func canHandle(_ job: Job) -> Bool {
        if case .pdfFrame = job.operation { return true }
        return false
    }

    public func run(
        _ job: Job,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> [URL] {
        guard let input = job.inputs.first else {
            throw EngineError.corruptInput("(missing file)")
        }
        guard case .pdfFrame(let spec) = job.operation else {
            throw EngineError.unsupported("\(job.operation)")
        }
        guard let document = PDFDocument(url: input), document.pageCount > 0 else {
            throw EngineError.corruptInput(input.lastPathComponent)
        }

        var background: CGImage?
        if case .image(let url) = spec.background {
            guard let loaded = ImageConvertEngine.loadImage(at: url) else {
                throw EngineError.corruptInput(url.lastPathComponent)
            }
            background = loaded
        }

        let dpi = CGFloat(max(72, min(spec.dpi, 400)))
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else {
            throw EngineError.writeFailed("could not create a PDF consumer")
        }
        var defaultBox = document.page(at: 0)?.bounds(for: .mediaBox)
            ?? CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let pdf = CGContext(consumer: consumer, mediaBox: &defaultBox, nil) else {
            throw EngineError.writeFailed("could not create a PDF context")
        }

        for index in 0..<document.pageCount {
            if Task.isCancelled { throw CancellationError() }
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)

            let width = max(1, Int((bounds.width * dpi / 72).rounded()))
            let height = max(1, Int((bounds.height * dpi / 72).rounded()))
            guard let pageContext = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else { continue }

            pageContext.setFillColor(NSColor.white.cgColor)
            pageContext.fill(CGRect(x: 0, y: 0, width: width, height: height))
            pageContext.scaleBy(x: dpi / 72, y: dpi / 72)
            page.draw(with: .mediaBox, to: pageContext)
            guard let pageImage = pageContext.makeImage(),
                  let framed = Self.renderPage(
                    pageImage: pageImage,
                    background: background,
                    spec: spec
                  ),
                  let jpeg = Self.jpegImage(framed) else { continue }

            let paddingPt = min(bounds.width, bounds.height) * min(max(spec.paddingPercent, 0), 0.4)
            let box = CGRect(
                x: 0, y: 0,
                width: bounds.width + paddingPt * 2,
                height: bounds.height + paddingPt * 2
            )
            let boxData = withUnsafeBytes(of: box) { Data($0) as CFData }
            pdf.beginPDFPage([kCGPDFContextMediaBox: boxData] as CFDictionary)
            pdf.draw(jpeg, in: box)
            pdf.endPDFPage()
            progress(Double(index + 1) / Double(document.pageCount))
        }
        pdf.closePDF()

        let base = input.deletingPathExtension().lastPathComponent
        let directory = input.deletingLastPathComponent()
        let candidate = directory.appendingPathComponent("\(base) Framed.pdf")
        let output = DestinationPolicy.unique(candidate)

        try writeAtomically(to: output) { tmp in
            try (data as Data).write(to: tmp, options: .atomic)
        }

        progress(1)
        return [output]
    }

    // MARK: Frame (also used by the preview)

    public static func renderPage(
        pageImage: CGImage,
        background: CGImage?,
        spec: PDFFrameSpec
    ) -> CGImage? {
        let paddingPercent = min(max(spec.paddingPercent, 0), 0.4)
        let padding = Int(Double(min(pageImage.width, pageImage.height)) * paddingPercent)
        let width = max(1, pageImage.width + padding * 2)
        let height = max(1, pageImage.height + padding * 2)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let canvas = CGRect(x: 0, y: 0, width: width, height: height)

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

        let pageRect = CGRect(
            x: padding,
            y: padding,
            width: pageImage.width,
            height: pageImage.height
        )

        if spec.shadow {
            context.saveGState()
            context.setShadow(
                offset: CGSize(width: 0, height: -CGFloat(max(4, padding / 4))),
                blur: CGFloat(max(8, padding / 2)),
                color: NSColor.black.withAlphaComponent(0.35).cgColor
            )
            context.setFillColor(NSColor.white.cgColor)
            context.fill(pageRect)
            context.restoreGState()
        }

        context.draw(pageImage, in: pageRect)
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

    private static func jpegImage(_ image: CGImage) -> CGImage? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(
            destination, image,
            [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
