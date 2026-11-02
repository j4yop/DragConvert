import XCTest
import AppKit
import ImageIO
@testable import JobCore
@testable import ImageEngine

final class ImageCropBatchTests: XCTestCase {

    func testSameRelativeCropAcrossDifferentSizes() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let wide = try makePNG(width: 200, height: 100, name: "wide.png", in: directory)
        let tall = try makePNG(width: 100, height: 200, name: "tall.png", in: directory)

        let spec = ImageCropBatchSpec(
            normalized: PDFRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        )
        let outputs = try await ImageCropBatchEngine().run(
            Job(inputs: [wide, tall], operation: .imageCropBatch(spec))
        ) { _ in }

        XCTAssertEqual(outputs.count, 2)
        XCTAssertEqual(outputs[0].lastPathComponent, "wide Cropped.png")
        XCTAssertEqual(outputs[1].lastPathComponent, "tall Cropped.png")

        let first = try load(outputs[0])
        XCTAssertEqual(first.width, 100)
        XCTAssertEqual(first.height, 50)

        let second = try load(outputs[1])
        XCTAssertEqual(second.width, 50)
        XCTAssertEqual(second.height, 100)
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

    private func load(_ url: URL) throws -> CGImage {
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        return try XCTUnwrap(source.flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) })
    }
}
