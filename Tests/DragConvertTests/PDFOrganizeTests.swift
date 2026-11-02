import XCTest
import AppKit
import PDFKit
@testable import JobCore
@testable import PDFEngine

final class PDFOrganizeTests: XCTestCase {

    func testReordersPages() async throws {
        let input = try makeRotatedPDF(rotations: [0, 90, 180])
        defer { try? FileManager.default.removeItem(at: input.deletingLastPathComponent()) }

        let spec = PDFOrganizeSpec(pages: [
            PDFPageEdit(sourceIndex: 2),
            PDFPageEdit(sourceIndex: 1),
            PDFPageEdit(sourceIndex: 0)
        ])
        let outputs = try await PDFOrganizeEngine().run(
            Job(inputs: [input], operation: .pdfOrganize(spec))
        ) { _ in }

        XCTAssertEqual(outputs[0].lastPathComponent, "source Organized.pdf")
        let result = try XCTUnwrap(PDFDocument(url: outputs[0]))
        XCTAssertEqual(result.pageCount, 3)
        XCTAssertEqual(rotations(result), [180, 90, 0])
    }

    func testRotatesAndDuplicatesAndRemoves() async throws {
        let input = try makeRotatedPDF(rotations: [0, 90, 180])
        defer { try? FileManager.default.removeItem(at: input.deletingLastPathComponent()) }

        let spec = PDFOrganizeSpec(pages: [
            PDFPageEdit(sourceIndex: 0, rotation: 1),
            PDFPageEdit(sourceIndex: 0),
            PDFPageEdit(sourceIndex: 2)
        ])
        let outputs = try await PDFOrganizeEngine().run(
            Job(inputs: [input], operation: .pdfOrganize(spec))
        ) { _ in }

        let result = try XCTUnwrap(PDFDocument(url: outputs[0]))
        XCTAssertEqual(result.pageCount, 3)
        XCTAssertEqual(rotations(result), [90, 0, 180])

        // Removing page 1 is simply omitting it from the spec.
        let shorter = PDFOrganizeSpec(pages: [
            PDFPageEdit(sourceIndex: 0),
            PDFPageEdit(sourceIndex: 2)
        ])
        let second = try await PDFOrganizeEngine().run(
            Job(inputs: [input], operation: .pdfOrganize(shorter))
        ) { _ in }
        XCTAssertEqual(try XCTUnwrap(PDFDocument(url: second[0])).pageCount, 2)
    }

    // MARK: Helpers

    private func makeRotatedPDF(rotations: [Int]) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("source.pdf")

        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        let context = try XCTUnwrap(CGContext(url as CFURL, mediaBox: &box, nil))
        for page in 0..<rotations.count {
            context.beginPDFPage(nil)
            let hue = CGFloat(page + 1) / CGFloat(max(1, rotations.count))
            context.setFillColor(NSColor(calibratedHue: hue, saturation: 0.4, brightness: 0.9, alpha: 1).cgColor)
            context.fill(box)
            context.endPDFPage()
        }
        context.closePDF()

        let document = try XCTUnwrap(PDFDocument(url: url))
        for (index, rotation) in rotations.enumerated() {
            document.page(at: index)?.rotation = rotation
        }
        XCTAssertTrue(document.write(to: url))
        return url
    }

    private func rotations(_ document: PDFDocument) -> [Int] {
        (0..<document.pageCount).compactMap { document.page(at: $0)?.rotation }
    }
}
