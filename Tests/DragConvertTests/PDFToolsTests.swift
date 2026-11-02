import XCTest
import AppKit
import PDFKit
@testable import JobCore
@testable import PDFEngine

final class PDFToolsTests: XCTestCase {

    func testMergeAddsPagesInOrder() async throws {
        let first = try makePDF(pages: 2, name: "first.pdf")
        let second = try makePDF(pages: 3, name: "second.pdf")
        defer {
            try? FileManager.default.removeItem(at: first.deletingLastPathComponent())
        }

        let outputs = try await PDFMergeEngine().run(
            Job(inputs: [first, second], operation: .pdfMerge)
        ) { _ in }

        XCTAssertEqual(outputs.count, 1)
        XCTAssertEqual(outputs[0].lastPathComponent, "first Merged.pdf")
        XCTAssertEqual(try pages(outputs[0]), 5)
    }

    func testSplitAtPageNumbers() async throws {
        let input = try makePDF(pages: 5, name: "source.pdf")
        defer { try? FileManager.default.removeItem(at: input.deletingLastPathComponent()) }

        let outputs = try await PDFSplitEngine().run(
            Job(
                inputs: [input],
                operation: .pdfSplit(PDFSplitSpec(mode: .atPages, pages: [3]))
            )
        ) { _ in }

        XCTAssertEqual(outputs.count, 2)
        XCTAssertEqual(outputs.map { $0.deletingLastPathComponent().lastPathComponent },
                       ["source Split", "source Split"])
        XCTAssertEqual(try pages(outputs[0]), 2)
        XCTAssertEqual(try pages(outputs[1]), 3)
    }

    func testSplitIntoEqualParts() async throws {
        let input = try makePDF(pages: 5, name: "source.pdf")
        defer { try? FileManager.default.removeItem(at: input.deletingLastPathComponent()) }

        let outputs = try await PDFSplitEngine().run(
            Job(
                inputs: [input],
                operation: .pdfSplit(PDFSplitSpec(mode: .equalParts, parts: 2))
            )
        ) { _ in }

        XCTAssertEqual(outputs.count, 2)
        XCTAssertEqual(try pages(outputs[0]), 3)
        XCTAssertEqual(try pages(outputs[1]), 2)
    }

    // MARK: Helpers

    private func makePDF(pages: Int, name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)

        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        let context = try XCTUnwrap(CGContext(url as CFURL, mediaBox: &mediaBox, nil))
        for page in 1...pages {
            context.beginPDFPage(nil)
            let hue = CGFloat(page) / CGFloat(max(1, pages))
            context.setFillColor(NSColor(calibratedHue: hue, saturation: 0.4, brightness: 0.9, alpha: 1).cgColor)
            context.fill(mediaBox)
            context.endPDFPage()
        }
        context.closePDF()
        return url
    }

    private func pages(_ url: URL) throws -> Int {
        try XCTUnwrap(PDFDocument(url: url)).pageCount
    }
}
