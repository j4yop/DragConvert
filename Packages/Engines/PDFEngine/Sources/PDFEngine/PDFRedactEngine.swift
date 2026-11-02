import Foundation
import AppKit
import PDFKit
import ImageIO
import UniformTypeIdentifiers
import JobCore
import EngineKit

/// True redaction: every page is rasterised at the chosen DPI and the redaction
/// areas are painted black **before** the new PDF is written. Text, vector
/// content and embedded images under a box do not survive, because the output
/// page is only pixels.
public struct PDFRedactEngine: Engine {
    public let id = "pdf.redact"

    public init() {}

    public func canHandle(_ job: Job) -> Bool {
        if case .pdfRedact = job.operation { return true }
        return false
    }

    public func run(
        _ job: Job,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> [URL] {
        guard let input = job.inputs.first else {
            throw EngineError.corruptInput("(missing file)")
        }
        guard case .pdfRedact(let spec) = job.operation else {
            throw EngineError.unsupported("\(job.operation)")
        }
        guard !spec.redactions.isEmpty else {
            throw EngineError.unsupported("Draw at least one redaction box")
        }
        guard let document = PDFDocument(url: input), document.pageCount > 0 else {
            throw EngineError.corruptInput(input.lastPathComponent)
        }

        let grouped = Dictionary(grouping: spec.redactions, by: \.pageIndex)
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
            let box = page.bounds(for: .mediaBox)

            let width = max(1, Int((box.width * dpi / 72).rounded()))
            let height = max(1, Int((box.height * dpi / 72).rounded()))
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
            bitmap.saveGState()
            bitmap.scaleBy(x: dpi / 72, y: dpi / 72)
            page.draw(with: .mediaBox, to: bitmap)
            bitmap.restoreGState()

            bitmap.saveGState()
            bitmap.setFillColor(NSColor.black.cgColor)
            for redaction in grouped[index] ?? [] {
                let rect = redaction.rect
                bitmap.fill(CGRect(
                    x: rect.x * Double(width),
                    y: (1 - rect.y - rect.height) * Double(height),
                    width: rect.width * Double(width),
                    height: rect.height * Double(height)
                ))
            }
            bitmap.restoreGState()

            guard let image = bitmap.makeImage(),
                  let jpeg = Self.jpegImage(image, quality: 0.9) else { continue }

            let pageBox = box
            let boxData = withUnsafeBytes(of: pageBox) { Data($0) as CFData }
            pdf.beginPDFPage([kCGPDFContextMediaBox: boxData] as CFDictionary)
            pdf.draw(jpeg, in: box)
            pdf.endPDFPage()
            progress(Double(index + 1) / Double(document.pageCount))
        }
        pdf.closePDF()

        let base = input.deletingPathExtension().lastPathComponent
        let directory = input.deletingLastPathComponent()
        let candidate = directory.appendingPathComponent("\(base) Redacted.pdf")
        let output = DestinationPolicy.unique(candidate)

        try writeAtomically(to: output) { tmp in
            try (data as Data).write(to: tmp, options: .atomic)
        }

        progress(1)
        return [output]
    }

    private static func jpegImage(_ image: CGImage, quality: Double) -> CGImage? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(
            destination, image,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
