import XCTest
import AppKit
import ImageIO
@testable import JobCore
@testable import ImageEngine

final class ImageCollageTests: XCTestCase {

    func testGridPlacesImagesInOrderOnTheCanvas() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let red = try makePNG(
            color: NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1),
            name: "red.png", in: directory
        )
        let green = try makePNG(
            color: NSColor(srgbRed: 0, green: 1, blue: 0, alpha: 1),
            name: "green.png", in: directory
        )
        let blue = try makePNG(
            color: NSColor(srgbRed: 0, green: 0, blue: 1, alpha: 1),
            name: "blue.png", in: directory
        )
        let yellow = try makePNG(
            color: NSColor(srgbRed: 1, green: 1, blue: 0, alpha: 1),
            name: "yellow.png", in: directory
        )

        let spec = ImageCollageSpec(
            layout: .grid,
            columns: 2,
            spacing: 10,
            cornerRadius: 0,
            background: ImageColor(red: 1, green: 1, blue: 1),
            canvasWidth: 220,
            format: "png"
        )
        let outputs = try await ImageCollageEngine().run(
            Job(inputs: [red, green, blue, yellow], operation: .imageCollage(spec))
        ) { _ in }

        XCTAssertEqual(outputs[0].lastPathComponent, "red Collage.png")
        let image = try load(outputs[0])
        XCTAssertEqual(image.width, 220)
        XCTAssertEqual(image.height, 220)

        let topLeft = pixel(image, x: 57, y: 57)
        XCTAssertGreaterThan(topLeft.0, 240)
        XCTAssertLessThan(topLeft.1, 20)
        XCTAssertLessThan(topLeft.2, 20)

        let topRight = pixel(image, x: 162, y: 57)
        XCTAssertLessThan(topRight.0, 20)
        XCTAssertGreaterThan(topRight.1, 240)
        XCTAssertLessThan(topRight.2, 20)

        let bottomLeft = pixel(image, x: 57, y: 162)
        XCTAssertLessThan(bottomLeft.0, 20)
        XCTAssertLessThan(bottomLeft.1, 20)
        XCTAssertGreaterThan(bottomLeft.2, 240)

        let bottomRight = pixel(image, x: 162, y: 162)
        XCTAssertGreaterThan(bottomRight.0, 240)
        XCTAssertGreaterThan(bottomRight.1, 240)
        XCTAssertLessThan(bottomRight.2, 20)
    }

    // MARK: Helpers

    private func makePNG(
        color: NSColor,
        name: String,
        in directory: URL
    ) throws -> URL {
        let url = directory.appendingPathComponent(name)
        let context = try XCTUnwrap(CGContext(
            data: nil, width: 100, height: 100,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(color.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
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
