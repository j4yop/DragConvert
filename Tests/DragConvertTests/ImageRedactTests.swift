import XCTest
import AppKit
import ImageIO
@testable import JobCore
@testable import ImageEngine

final class ImageRedactTests: XCTestCase {

    func testRedactionReplacesPixelsWithBlack() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let input = try makePNG(
            color: NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1),
            width: 200,
            height: 100,
            in: directory
        )
        let spec = ImageRedactSpec(
            redactions: [PDFRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)],
            format: "png"
        )
        let outputs = try await ImageRedactEngine().run(
            Job(inputs: [input], operation: .imageRedact(spec))
        ) { _ in }

        XCTAssertEqual(outputs[0].lastPathComponent, "source Redacted.png")
        let image = try load(outputs[0])
        XCTAssertEqual(image.width, 200)
        XCTAssertEqual(image.height, 100)

        let inside = pixel(image, x: 100, y: 50)
        XCTAssertLessThan(inside.0, 20)
        XCTAssertLessThan(inside.1, 20)
        XCTAssertLessThan(inside.2, 20)

        let outside = pixel(image, x: 160, y: 20)
        XCTAssertGreaterThan(outside.0, 240)
        XCTAssertLessThan(outside.1, 20)
        XCTAssertLessThan(outside.2, 20)
    }

    // MARK: Helpers

    private func makePNG(
        color: NSColor,
        width: Int,
        height: Int,
        in directory: URL
    ) throws -> URL {
        let url = directory.appendingPathComponent("source.png")
        let context = try XCTUnwrap(CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(color.cgColor)
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

    private func pixel(_ image: CGImage, x: Int, y: Int) -> (Int, Int, Int) {
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
        ) else { return (0, 0, 0) }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let index = (y * width + x) * 4
        return (Int(pixels[index]), Int(pixels[index + 1]), Int(pixels[index + 2]))
    }
}
