import Foundation
import AppKit
import PDFKit
import Vision
import CoreGraphics
import ImageEngine

extension QRCodeReader {
    /// Renders the first PDF page at a readable scale and reuses the image
    /// barcode detector.
    public static func decodePDF(at url: URL) -> [String] {
        guard let document = PDFDocument(url: url),
              let page = document.page(at: 0) else { return [] }
        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 3
        let width = max(1, Int(bounds.width * scale))
        let height = max(1, Int(bounds.height * scale))
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
        guard let image = context.makeImage() else { return [] }

        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try? handler.perform([request])
        let values = (request.results ?? []).compactMap(\.payloadStringValue)
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
