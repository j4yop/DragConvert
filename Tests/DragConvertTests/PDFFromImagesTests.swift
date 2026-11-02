import XCTest
import AppKit
import PDFKit
@testable import JobCore
@testable import PDFEngine

final class PDFFromImagesTests: XCTestCase {

    func testBuildsOnePagePerImageInOrder() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = try makePNG(width: 100, height: 80, name: "first.png", in: directory)
        let second = try makePNG(width: 200, height: 120, name: "second.png", in: directory)
        let third = try makePNG(width: 60, height: 60, name: "third.png", in: directory)

        let outputs = try await PDFFromImagesEngine().run(
            Job(inputs: [first, second, third], operation: .pdfFromImages)
        ) { _ in }

        XCTAssertEqual(outputs[0].lastPathComponent, "first Images.pdf")
        let document = try XCTUnwrap(PDFDocument(url: outputs[0]))
        XCTAssertEqual(document.pageCount, 3)

        let expected = [CGSize(width: 100, height: 80),
                        CGSize(width: 200, height: 120),
                        CGSize(width: 60, height: 60)]
        for (index, size) in expected.enumerated() {
            let box = try XCTUnwrap(document.page(at: index)).bounds(for: .mediaBox)
            XCTAssertEqual(box.width, size.width, accuracy: 1)
            XCTAssertEqual(box.height, size.height, accuracy: 1)
        }
    }

    // MARK: Helpers

    private func makePNG(
        width: Int,
        height: Int,
        name: String,
        in directory: URL
    ) throws -> URL {
        let url = directory.appendingPathComponent(name)
        let context = try XCTUnwrap(CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(NSColor.systemOrange.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try XCTUnwrap(context.makeImage())

        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(
            url as CFURL, "public.png" as CFString, 1, nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return url
    }
}
