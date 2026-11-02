import XCTest
import AppKit
import CoreText
import PDFKit
@testable import JobCore
@testable import PDFEngine

final class PDFTextTests: XCTestCase {

    func testSelectablePDFToTextAndMarkdown() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let input = directory.appendingPathComponent("notes.pdf")
        try makePDF(text: "Quarterly report\nRevenue is up.", to: input)

        let textJob = Job(inputs: [input], operation: .convert(to: "txt"))
        let textURL = try await PDFTextEngine(ocrDPI: 72).run(textJob) { _ in }[0]
        let text = try String(contentsOf: textURL, encoding: .utf8)
        XCTAssertTrue(text.contains("Quarterly report"), text)
        XCTAssertTrue(text.contains("Revenue"), text)

        let markdownJob = Job(inputs: [input], operation: .convert(to: "md"))
        let markdownURL = try await PDFTextEngine(ocrDPI: 72).run(markdownJob) { _ in }[0]
        let markdown = try String(contentsOf: markdownURL, encoding: .utf8)
        XCTAssertTrue(markdown.hasPrefix("# notes"), markdown)
        XCTAssertTrue(markdown.contains("Quarterly report"), markdown)
    }

    private func makePDF(text: String, to url: URL) throws {
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw XCTSkip("could not create a PDF context")
        }

        context.beginPDFPage(nil)
        let attributed = NSAttributedString(
            string: text,
            attributes: [.font: NSFont.systemFont(ofSize: 22)]
        )
        let line = CTLineCreateWithAttributedString(attributed)
        context.textPosition = CGPoint(x: 72, y: 680)
        CTLineDraw(line, context)
        context.endPDFPage()
        context.closePDF()

        try (data as Data).write(to: url)
    }
}
