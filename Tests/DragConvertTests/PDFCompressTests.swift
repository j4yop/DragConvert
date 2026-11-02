import XCTest
import AppKit
import PDFKit
@testable import JobCore
@testable import PDFEngine

final class PDFCompressTests: XCTestCase {

    func testBalancedPreservesPageCount() async throws {
        let input = try makeImagePDF(pages: 3)
        defer { try? FileManager.default.removeItem(at: input.deletingLastPathComponent()) }

        let outputs = try await PDFCompressEngine().run(
            Job(
                inputs: [input],
                operation: .pdfCompress(PDFCompressSpec(mode: .balanced))
            )
        ) { _ in }

        XCTAssertEqual(outputs[0].lastPathComponent, "source Compressed.pdf")
        XCTAssertEqual(try pages(outputs[0]), 3)
    }

    func testTargetSizeIsRespected() async throws {
        let input = try makeImagePDF(pages: 1)
        defer { try? FileManager.default.removeItem(at: input.deletingLastPathComponent()) }

        let originalSize = try fileSize(input)
        XCTAssertGreaterThan(originalSize, 200 * 1024)

        let target = 200 * 1024
        let outputs = try await PDFCompressEngine().run(
            Job(
                inputs: [input],
                operation: .pdfCompress(
                    PDFCompressSpec(mode: .targetSize, targetBytes: target)
                )
            )
        ) { _ in }

        let outputSize = try fileSize(outputs[0])
        XCTAssertLessThanOrEqual(outputSize, target + 20 * 1024)
        XCTAssertEqual(try pages(outputs[0]), 1)
    }

    func testDoesNotInflateASmallPDF() async throws {
        let input = try makeVectorPDF(pages: 2)
        defer { try? FileManager.default.removeItem(at: input.deletingLastPathComponent()) }

        let originalSize = try fileSize(input)
        let outputs = try await PDFCompressEngine().run(
            Job(
                inputs: [input],
                operation: .pdfCompress(
                    PDFCompressSpec(mode: .targetSize, targetBytes: 10 * 1024 * 1024)
                )
            )
        ) { _ in }

        XCTAssertLessThanOrEqual(try fileSize(outputs[0]), originalSize)
    }

    // MARK: Helpers

    private func makeImagePDF(pages: Int) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("source.pdf")

        let image = try noiseImage(width: 1400, height: 1000)
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        let context = try XCTUnwrap(CGContext(url as CFURL, mediaBox: &box, nil))
        for _ in 0..<pages {
            context.beginPDFPage(nil)
            context.setFillColor(NSColor.white.cgColor)
            context.fill(box)
            context.draw(image, in: box)
            context.endPDFPage()
        }
        context.closePDF()
        return url
    }

    private func makeVectorPDF(pages: Int) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("source.pdf")

        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        let context = try XCTUnwrap(CGContext(url as CFURL, mediaBox: &box, nil))
        for page in 0..<pages {
            context.beginPDFPage(nil)
            context.setFillColor(NSColor(calibratedHue: CGFloat(page) / 3, saturation: 0.3, brightness: 0.9, alpha: 1).cgColor)
            context.fill(box)
            context.endPDFPage()
        }
        context.closePDF()
        return url
    }

    private func noiseImage(width: Int, height: Int) throws -> CGImage {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for index in stride(from: 0, to: pixels.count, by: 4) {
            pixels[index] = UInt8.random(in: 0...255)
            pixels[index + 1] = UInt8.random(in: 0...255)
            pixels[index + 2] = UInt8.random(in: 0...255)
            pixels[index + 3] = 255
        }
        let provider = try XCTUnwrap(CGDataProvider(data: Data(pixels) as CFData))
        return try XCTUnwrap(CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ))
    }

    private func pages(_ url: URL) throws -> Int {
        try XCTUnwrap(PDFDocument(url: url)).pageCount
    }

    private func fileSize(_ url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return try XCTUnwrap((attributes[.size] as? NSNumber)?.intValue)
    }
}
