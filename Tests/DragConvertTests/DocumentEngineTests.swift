import XCTest
import AppKit
import CoreText
import ImageIO
import PDFKit
@testable import JobCore
@testable import PDFEngine
@testable import DocumentEngine

final class DocumentEngineTests: XCTestCase {

    func testCSVToXLSXAndBackKeepsRows() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("people.csv")
        let csv = "Name,Role,Notes\r\n"
            + "Ada Lovelace,Engineer,\"First, programmer\"\r\n"
            + "Grace Hopper,Admiral,\"Compiler \"\"pioneer\"\"\"\r\n"
        try csv.write(to: source, atomically: true, encoding: .utf8)

        let engine = SpreadsheetEngine()
        let xlsx = try await engine.run(
            Job(inputs: [source], operation: .convert(to: "xlsx"))
        ) { _ in }[0]
        XCTAssertTrue(FileManager.default.fileExists(atPath: xlsx.path))

        let back = try await engine.run(
            Job(inputs: [xlsx], operation: .convert(to: "csv"))
        ) { _ in }[0]
        let text = try String(contentsOf: back, encoding: .utf8)
        XCTAssertTrue(text.contains("Ada Lovelace,Engineer,\"First, programmer\""), text)
        XCTAssertTrue(text.contains("\"Compiler \"\"pioneer\"\"\""), text)
    }

    func testCSVToODSAndBackKeepsRows() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("people.tsv")
        try "Name\tScore\nAda\t98\nGrace\t96\n"
            .write(to: source, atomically: true, encoding: .utf8)

        let engine = SpreadsheetEngine()
        let ods = try await engine.run(
            Job(inputs: [source], operation: .convert(to: "ods"))
        ) { _ in }[0]
        let back = try await engine.run(
            Job(inputs: [ods], operation: .convert(to: "tsv"))
        ) { _ in }[0]
        let text = try String(contentsOf: back, encoding: .utf8)
        XCTAssertTrue(text.contains("Ada\t98"), text)
        XCTAssertTrue(text.contains("Grace\t96"), text)
    }

    func testSpreadsheetNumberDetectionSetting() async throws {
        let key = "conversionProfile.xlsx.spreadsheetNumbers"
        UserDefaults.standard.set(false, forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }

        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("codes.csv")
        try "Code,Count\n00123,42\n".write(
            to: source, atomically: true, encoding: .utf8
        )

        let xlsx = try await SpreadsheetEngine().run(
            Job(inputs: [source], operation: .convert(to: "xlsx"))
        ) { _ in }[0]

        guard let archive = ZipReader(url: xlsx),
              let sheet = archive.readText("xl/worksheets/sheet1.xml") else {
            return XCTFail("could not inspect the workbook")
        }
        XCTAssertTrue(sheet.contains("00123"), sheet)
        XCTAssertFalse(sheet.contains("<v>00123</v>"), sheet)
        XCTAssertFalse(sheet.contains("<v>42</v>"), sheet)
        XCTAssertFalse(ConversionDefaults.detectsSpreadsheetNumbers(for: "xlsx"))
    }

    func testTextDocumentToPDFAndImages() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("notes.md")
        try "# Notes\n\nLocal conversion only.\n".write(
            to: source, atomically: true, encoding: .utf8
        )

        let engine = DocumentConversionEngine()
        let pdf = try await engine.run(
            Job(inputs: [source], operation: .convert(to: "pdf"))
        ) { _ in }[0]
        guard let document = PDFDocument(url: pdf) else {
            return XCTFail("PDF was not created")
        }
        XCTAssertEqual(document.pageCount, 1)
        XCTAssertTrue(document.string?.contains("Local conversion only") ?? false)

        let png = try await engine.run(
            Job(inputs: [source], operation: .convert(to: "png"))
        ) { _ in }[0]
        guard let imageSource = CGImageSourceCreateWithURL(png as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return XCTFail("PNG was not created")
        }
        XCTAssertGreaterThan(image.width, 100)
        XCTAssertGreaterThan(image.height, 100)
    }

    func testDOCXToPDFUsesTheNativeReader() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("notes.docx")
        try DocumentWriters.writeDOCX(
            ["Field Notes\nA local conversion.\nImages and PDFs work."],
            title: "notes",
            to: source
        )

        let pdf = try await DocumentConversionEngine().run(
            Job(inputs: [source], operation: .convert(to: "pdf"))
        ) { _ in }[0]

        guard let document = PDFDocument(url: pdf) else {
            return XCTFail("DOCX did not become a PDF")
        }
        XCTAssertEqual(document.pageCount, 1)
        XCTAssertTrue(document.string?.contains("Field Notes") ?? false)
        XCTAssertTrue(document.string?.contains("A local conversion") ?? false)
    }

    func testPDFDocumentExportsHTMLDOCXAndEPUB() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("report.pdf")
        try makePDF(text: "Quarterly report\nRevenue is up.", to: source)

        let engine = PDFDocumentEngine()
        for target in ["html", "docx", "epub", "rtf"] {
            let output = try await engine.run(
                Job(inputs: [source], operation: .convert(to: target))
            ) { _ in }[0]
            XCTAssertTrue(FileManager.default.fileExists(atPath: output.path), target)
        }

        let docx = directory.appendingPathComponent("report.docx")
        guard let archive = ZipReader(url: docx) else {
            return XCTFail("DOCX is not a readable zip")
        }
        XCTAssertNotNil(archive.read("word/document.xml"))

        let epub = directory.appendingPathComponent("report.epub")
        guard let epubArchive = ZipReader(url: epub) else {
            return XCTFail("EPUB is not a readable zip")
        }
        XCTAssertEqual(epubArchive.names.first, "mimetype")
        XCTAssertEqual(epubArchive.readText("mimetype"), "application/epub+zip")
        XCTAssertNotNil(epubArchive.read("OEBPS/content.opf"))
    }

    func testPDFToBMPUsesImageIO() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("report.pdf")
        try makePDF(text: "Bitmap page", to: source)

        let output = try await PDFToImageEngine(dpi: 120).run(
            Job(inputs: [source], operation: .convert(to: "bmp"))
        ) { _ in }[0]

        guard let sourceImage = CGImageSourceCreateWithURL(output as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(sourceImage, 0, nil) else {
            return XCTFail("BMP could not be read")
        }
        XCTAssertEqual(output.pathExtension.lowercased(), "bmp")
        XCTAssertGreaterThan(image.width, image.height / 2)
    }

    // MARK: Helpers

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
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
