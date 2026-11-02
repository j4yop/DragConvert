import XCTest
import AppKit
import PDFKit
@testable import JobCore
@testable import PDFEngine

final class PDFAnnotateTests: XCTestCase {

    func testWritesAnnotationsToTheRightPages() async throws {
        let input = try makePDF(pages: 2)
        defer { try? FileManager.default.removeItem(at: input.deletingLastPathComponent()) }

        let red = PDFColor(red: 1, green: 0.23, blue: 0.19)
        let blue = PDFColor(red: 0, green: 0.48, blue: 1)
        let spec = PDFAnnotateSpec(annotations: [
            PDFAnnotationSpec(
                kind: .rectangle,
                pageIndex: 0,
                rect: PDFRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2),
                color: red
            ),
            PDFAnnotationSpec(
                kind: .ink,
                pageIndex: 0,
                points: [
                    PDFPoint(x: 0.2, y: 0.6),
                    PDFPoint(x: 0.3, y: 0.65),
                    PDFPoint(x: 0.4, y: 0.6)
                ],
                color: red
            ),
            PDFAnnotationSpec(
                kind: .text,
                pageIndex: 1,
                rect: PDFRect(x: 0.1, y: 0.1, width: 0.3, height: 0.1),
                text: "Hello",
                color: blue
            ),
            PDFAnnotationSpec(
                kind: .arrow,
                pageIndex: 1,
                points: [PDFPoint(x: 0.2, y: 0.5), PDFPoint(x: 0.6, y: 0.7)],
                color: blue
            )
        ])

        let outputs = try await PDFAnnotateEngine().run(
            Job(inputs: [input], operation: .pdfAnnotate(spec))
        ) { _ in }

        XCTAssertEqual(outputs[0].lastPathComponent, "source Annotated.pdf")
        let document = try XCTUnwrap(PDFDocument(url: outputs[0]))
        XCTAssertEqual(document.pageCount, 2)

        let first = try XCTUnwrap(document.page(at: 0))
        XCTAssertEqual(first.annotations.count, 2)
        XCTAssertTrue(first.annotations.contains { $0.type == "Square" })
        XCTAssertTrue(first.annotations.contains { $0.type == "Ink" })

        let second = try XCTUnwrap(document.page(at: 1))
        XCTAssertEqual(second.annotations.count, 2)
        XCTAssertTrue(second.annotations.contains { $0.type == "FreeText" })
        XCTAssertTrue(second.annotations.contains { $0.type == "Line" })
        XCTAssertTrue(second.annotations.contains { $0.contents == "Hello" })
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
            context.setFillColor(NSColor(calibratedHue: CGFloat(page) / 4, saturation: 0.25, brightness: 0.95, alpha: 1).cgColor)
            context.fill(box)
            context.endPDFPage()
        }
        context.closePDF()
        return url
    }
}
