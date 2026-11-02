import Foundation
import AppKit
import PDFKit
import ImageIO
import UniformTypeIdentifiers
import JobCore
import EngineKit

public struct PDFCompressEngine: Engine {
    public let id = "pdf.compress"

    public init() {}

    public func canHandle(_ job: Job) -> Bool {
        if case .pdfCompress = job.operation { return true }
        return false
    }

    public func run(
        _ job: Job,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> [URL] {
        guard let input = job.inputs.first else {
            throw EngineError.corruptInput("(missing file)")
        }
        guard case .pdfCompress(let spec) = job.operation else {
            throw EngineError.unsupported("\(job.operation)")
        }
        guard let document = PDFDocument(url: input), document.pageCount > 0 else {
            throw EngineError.corruptInput(input.lastPathComponent)
        }

        let originalBytes = ((try? FileManager.default.attributesOfItem(atPath: input.path))?[.size] as? NSNumber)?.intValue ?? 0

        let data: Data
        switch spec.mode {
        case .balanced:
            guard let encoded = Self.balanced(document) else {
                throw EngineError.writeFailed("PDFKit could not rewrite the document")
            }
            data = encoded
        case .targetSize:
            guard let encoded = Self.targetSize(document, targetBytes: spec.targetBytes) else {
                throw EngineError.writeFailed("could not compress the document")
            }
            data = encoded
        }

        let base = input.deletingPathExtension().lastPathComponent
        let directory = input.deletingLastPathComponent()
        let candidate = directory.appendingPathComponent("\(base) Compressed.pdf")
        let output = DestinationPolicy.unique(candidate)

        if originalBytes > 0, data.count >= originalBytes {
            // Never inflate the original.
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

    // MARK: Balanced (keeps text, recompresses images)

    static func balanced(_ document: PDFDocument) -> Data? {
        if #available(macOS 13.4, *) {
            let options: [PDFDocumentWriteOption: Any] = [
                .saveImagesAsJPEGOption: true,
                .optimizeImagesForScreenOption: true
            ]
            return document.dataRepresentation(options: options)
        }
        return document.dataRepresentation()
    }

    // MARK: Target size (rasterises pages)

    static func targetSize(_ document: PDFDocument, targetBytes: Int) -> Data? {
        let attempts: [(dpi: CGFloat, quality: Double)] = [
            (150, 0.72), (150, 0.55), (130, 0.60), (120, 0.50),
            (110, 0.45), (96, 0.50), (96, 0.35), (72, 0.40), (72, 0.30)
        ]

        var smallest: Data?
        for attempt in attempts {
            guard let data = rasterise(
                document, dpi: attempt.dpi, quality: attempt.quality
            ) else { continue }
            smallest = data
            if data.count <= targetBytes { return data }
        }
        return smallest
    }

    private static func rasterise(
        _ document: PDFDocument,
        dpi: CGFloat,
        quality: Double
    ) -> Data? {
        guard let firstPage = document.page(at: 0) else { return nil }
        var mediaBox = firstPage.bounds(for: .mediaBox)

        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let pdf = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else { return nil }

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)

            let width = max(1, Int((bounds.width * dpi / 72).rounded()))
            let height = max(1, Int((bounds.height * dpi / 72).rounded()))

            guard let bitmap = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else { continue }

            bitmap.setFillColor(NSColor.white.cgColor)
            bitmap.fill(CGRect(x: 0, y: 0, width: width, height: height))
            bitmap.scaleBy(x: dpi / 72, y: dpi / 72)
            page.draw(with: .mediaBox, to: bitmap)
            guard let image = bitmap.makeImage() else { continue }

            let jpeg = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(
                jpeg as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil
            ) else { continue }
            CGImageDestinationAddImage(
                destination, image,
                [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
            )
            guard CGImageDestinationFinalize(destination),
                  let source = CGImageSourceCreateWithData(jpeg as CFData, nil),
                  let jpegImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else { continue }

            pdf.beginPDFPage(nil)
            pdf.draw(jpegImage, in: bounds)
            pdf.endPDFPage()
        }

        pdf.closePDF()
        return data as Data
    }
}
