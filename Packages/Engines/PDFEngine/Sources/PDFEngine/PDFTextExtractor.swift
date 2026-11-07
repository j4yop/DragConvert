import AppKit
import CoreGraphics
import Foundation
import PDFKit
import Vision

/// Selectable text first, then on-device Vision OCR for scanned pages.
public enum PDFTextExtractor {
    public static func pages(
        from document: PDFDocument,
        ocrDPI: CGFloat = 150
    ) -> [String] {
        (0..<document.pageCount).map { index in
            text(document.page(at: index), ocrDPI: ocrDPI)
        }
    }

    public static func text(_ page: PDFPage?, ocrDPI: CGFloat = 150) -> String {
        guard let page else { return "" }

        if let selectable = page.string?.trimmingCharacters(in: .whitespacesAndNewlines),
           !selectable.isEmpty {
            return selectable
        }

        guard let image = rasterise(page, dpi: ocrDPI) else {
            return page.string ?? ""
        }
        return recognise(image) ?? (page.string ?? "")
    }

    public static func rasterise(_ page: PDFPage, dpi: CGFloat) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        let scale = dpi / 72
        let width = max(1, Int((bounds.width * scale).rounded()))
        let height = max(1, Int((bounds.height * scale).rounded()))

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }

        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.saveGState()
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
        context.restoreGState()
        return context.makeImage()
    }

    private static func recognise(_ image: CGImage) -> String? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            NSLog("[dragconvert] pdf ocr failed: \(error.localizedDescription)")
            return nil
        }

        let observations = (request.results ?? []).sorted { left, right in
            if abs(left.boundingBox.maxY - right.boundingBox.maxY) > 0.01 {
                return left.boundingBox.maxY > right.boundingBox.maxY
            }
            return left.boundingBox.minX < right.boundingBox.minX
        }

        let lines = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }
        let text = lines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
