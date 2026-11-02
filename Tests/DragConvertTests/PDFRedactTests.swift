import XCTest
import AppKit
import PDFKit
@testable import JobCore
@testable import PDFEngine

final class PDFRedactTests: XCTestCase {

    func testRedactionRemovesTextAndPaintsBlack() async throws {
        let input = try makeTextPDF()
        defer { try? FileManager.default.removeItem(at: input.deletingLastPathComponent()) }

        let before = try XCTUnwrap(PDFDocument(url: input))
        XCTAssertTrue((before.page(at: 0)?.string ?? "").contains("SECRET"))

        let spec = PDFRedactSpec(
            redactions: [
                PDFRedaction(
                    pageIndex: 0,
                    rect: PDFRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2)
                )
            ],
            dpi: 200
        )
        let outputs = try await PDFRedactEngine().run(
            Job(inputs: [input], operation: .pdfRedact(spec))
        ) { _ in }

        XCTAssertEqual(outputs[0].lastPathComponent, "source Redacted.pdf")
        let result = try XCTUnwrap(PDFDocument(url: outputs[0]))
        XCTAssertEqual(result.pageCount, 2)

        // Rasterised pages carry no selectable text at all, redacted or not.
        XCTAssertTrue((result.page(at: 0)?.string ?? "").isEmpty)
        XCTAssertTrue((result.page(at: 1)?.string ?? "").isEmpty)

        let redacted = try render(try XCTUnwrap(result.page(at: 0)))
        XCTAssertGreaterThan(blackFraction(redacted), 0.02)
        XCTAssertLessThan(blackFraction(redacted), 0.20)

        let untouched = try render(try XCTUnwrap(result.page(at: 1)))
        XCTAssertLessThan(blackFraction(untouched), 0.02)
    }

    // MARK: Helpers

    private func makeTextPDF() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("source.pdf")

        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        let context = try XCTUnwrap(CGContext(url as CFURL, mediaBox: &box, nil))
        for text in ["SECRET TEXT", "PUBLIC TEXT"] {
            context.beginPDFPage(nil)
            context.setFillColor(NSColor.white.cgColor)
            context.fill(box)

            let graphics = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = graphics
            (text as NSString).draw(
                at: NSPoint(x: 72, y: 700),
                withAttributes: [
                    .font: NSFont.systemFont(ofSize: 24),
                    .foregroundColor: NSColor.black
                ]
            )
            NSGraphicsContext.restoreGraphicsState()
            context.endPDFPage()
        }
        context.closePDF()
        return url
    }

    private func render(_ page: PDFPage, dpi: CGFloat = 150) throws -> CGImage {
        let bounds = page.bounds(for: .mediaBox)
        let width = max(1, Int(bounds.width * dpi / 72))
        let height = max(1, Int(bounds.height * dpi / 72))
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: dpi / 72, y: dpi / 72)
        page.draw(with: .mediaBox, to: context)
        return try XCTUnwrap(context.makeImage())
    }

    private func blackFraction(_ image: CGImage) -> Double {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 0 }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var black = 0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            if pixels[index] < 40 && pixels[index + 1] < 40 && pixels[index + 2] < 40 {
                black += 1
            }
        }
        return Double(black) / Double(width * height)
    }
}
