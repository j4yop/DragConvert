import XCTest
import AppKit
import PDFKit
@testable import JobCore
@testable import PDFEngine

final class PDFFrameTests: XCTestCase {

    func testFramesEveryPageWithPadding() async throws {
        let input = try makePDF(pages: 2)
        defer { try? FileManager.default.removeItem(at: input.deletingLastPathComponent()) }

        let spec = PDFFrameSpec(
            paddingPercent: 0.1,
            shadow: false,
            background: .color(ImageColor(red: 1, green: 1, blue: 1)),
            dpi: 200
        )
        let outputs = try await PDFFrameEngine().run(
            Job(inputs: [input], operation: .pdfFrame(spec))
        ) { _ in }

        XCTAssertEqual(outputs[0].lastPathComponent, "source Framed.pdf")
        let document = try XCTUnwrap(PDFDocument(url: outputs[0]))
        XCTAssertEqual(document.pageCount, 2)

        let page = try XCTUnwrap(document.page(at: 0))
        let box = page.bounds(for: .mediaBox)
        XCTAssertEqual(box.width, 612 + 61.2 * 2, accuracy: 1)
        XCTAssertEqual(box.height, 792 + 61.2 * 2, accuracy: 1)

        let rendered = try render(page, dpi: 100)
        let corner = pixel(rendered, x: 5, y: 5)
        XCTAssertGreaterThan(corner.0, 240)
        XCTAssertGreaterThan(corner.1, 240)
        XCTAssertGreaterThan(corner.2, 240)

        let center = pixel(rendered, x: rendered.width / 2, y: rendered.height / 2)
        XCTAssertGreaterThan(center.0, 200)
        XCTAssertLessThan(center.1, 200)
        XCTAssertLessThan(center.2, 80)
    }

    // MARK: Helpers

    private func makePDF(pages: Int) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("source.pdf")

        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        let context = try XCTUnwrap(CGContext(url as CFURL, mediaBox: &box, nil))
        for _ in 0..<pages {
            context.beginPDFPage(nil)
            context.setFillColor(NSColor.systemOrange.cgColor)
            context.fill(box)
            context.endPDFPage()
        }
        context.closePDF()
        return url
    }

    private func render(_ page: PDFPage, dpi: CGFloat) throws -> CGImage {
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

    private func pixel(_ image: CGImage, x: Int, y: Int) -> (Int, Int, Int) {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return (0, 0, 0) }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let index = (y * width + x) * 4
        return (Int(pixels[index]), Int(pixels[index + 1]), Int(pixels[index + 2]))
    }
}
