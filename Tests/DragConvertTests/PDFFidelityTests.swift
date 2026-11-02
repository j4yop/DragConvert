import XCTest
import AppKit
import PDFKit
@testable import JobCore
@testable import PDFEngine

final class PDFFidelityTests: XCTestCase {

    func testBalancedCompressionKeepsAnnotations() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appendingPathComponent("annotated.pdf")
        try makeAnnotatedPDF(at: input)

        let job = Job(
            inputs: [input],
            operation: .pdfCompress(PDFCompressSpec(mode: .balanced))
        )
        let output = try await PDFCompressEngine().run(job) { _ in }[0]
        let compressed = PDFDocument(url: output)
        XCTAssertGreaterThan(compressed?.page(at: 0)?.annotations.count ?? 0, 0)
    }

    func testPDFToImageKeepsVisibleAnnotations() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appendingPathComponent("annotated.pdf")
        try makeAnnotatedPDF(at: input)

        let job = Job(inputs: [input], operation: .convert(to: "png"))
        let output = try await PDFToImageEngine(dpi: 150).run(job) { _ in }[0]

        guard let source = CGImageSourceCreateWithURL(output as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return XCTFail("could not read the rendered page")
        }

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
        ) else {
            return XCTFail("could not create a bitmap context")
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var redPixels = 0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            if pixels[index] > 170, pixels[index + 1] < 110, pixels[index + 2] < 110 {
                redPixels += 1
            }
        }
        XCTAssertGreaterThan(redPixels, 100, "the red annotation should be visible in the PNG")
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func makeAnnotatedPDF(at url: URL) throws {
        let document = PDFDocument()
        let page = PDFPage()
        document.insert(page, at: 0)

        let annotation = PDFAnnotation(
            bounds: CGRect(x: 100, y: 100, width: 120, height: 70),
            forType: .square,
            withProperties: nil
        )
        annotation.color = .systemRed
        let border = PDFBorder()
        border.lineWidth = 6
        annotation.border = border
        page.addAnnotation(annotation)

        guard document.write(to: url) else {
            throw XCTSkip("could not write the annotated PDF")
        }
    }
}
