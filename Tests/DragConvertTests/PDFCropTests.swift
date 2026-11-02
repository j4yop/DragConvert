import XCTest
import AppKit
import PDFKit
@testable import JobCore
@testable import PDFEngine

final class PDFCropTests: XCTestCase {

    func testCropAppliesToEveryPage() async throws {
        let input = try makePDF(pages: 2)
        defer { try? FileManager.default.removeItem(at: input.deletingLastPathComponent()) }

        let spec = PDFCropSpec(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        let outputs = try await PDFCropEngine().run(
            Job(inputs: [input], operation: .pdfCrop(spec))
        ) { _ in }

        XCTAssertEqual(outputs[0].lastPathComponent, "source Cropped.pdf")
        let result = try XCTUnwrap(PDFDocument(url: outputs[0]))
        XCTAssertEqual(result.pageCount, 2)

        for index in 0..<result.pageCount {
            let box = try XCTUnwrap(result.page(at: index)).bounds(for: .mediaBox)
            // PDFKit normalises the cropped page's origin to (0, 0) on write;
            // the size is what matters for the crop.
            XCTAssertEqual(box.width, 306, accuracy: 0.5)
            XCTAssertEqual(box.height, 396, accuracy: 0.5)
        }
    }

    func testCropIsClampedToThePage() async throws {
        let input = try makePDF(pages: 1)
        defer { try? FileManager.default.removeItem(at: input.deletingLastPathComponent()) }

        let spec = PDFCropSpec(x: 0.8, y: 0.1, width: 0.5, height: 0.5)
        let outputs = try await PDFCropEngine().run(
            Job(inputs: [input], operation: .pdfCrop(spec))
        ) { _ in }

        let page = try XCTUnwrap(PDFDocument(url: outputs[0])?.page(at: 0))
        let box = page.bounds(for: .mediaBox)
        XCTAssertEqual(box.width, 612 * 0.2, accuracy: 0.5)
        XCTAssertEqual(box.height, 792 * 0.5, accuracy: 0.5)
    }

    // MARK: Helpers

    private func makePDF(pages: Int) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("source.pdf")

        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        let context = try XCTUnwrap(CGContext(url as CFURL, mediaBox: &box, nil))
        for page in 0..<pages {
            context.beginPDFPage(nil)
            context.setFillColor(NSColor(calibratedHue: CGFloat(page) / 4, saturation: 0.3, brightness: 0.9, alpha: 1).cgColor)
            context.fill(box)
            context.endPDFPage()
        }
        context.closePDF()
        return url
    }
}
