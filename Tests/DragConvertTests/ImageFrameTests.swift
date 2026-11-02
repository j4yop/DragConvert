import XCTest
import AppKit
import ImageIO
@testable import JobCore
@testable import ImageEngine

final class ImageFrameTests: XCTestCase {

    func testColorBackgroundAddsPadding() async throws {
        let (directory, input) = try makePNG(
            color: NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1), width: 200, height: 100, name: "source.png"
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let spec = ImageFrameSpec(
            paddingPercent: 0.25,
            cornerRadius: 0,
            shadow: false,
            background: .color(ImageColor(red: 1, green: 1, blue: 1)),
            format: "png"
        )
        let outputs = try await ImageFrameEngine().run(
            Job(inputs: [input], operation: .imageFrame(spec))
        ) { _ in }

        XCTAssertEqual(outputs[0].lastPathComponent, "source Framed.png")
        let image = try load(outputs[0])
        XCTAssertEqual(image.width, 250)
        XCTAssertEqual(image.height, 150)

        let corner = pixel(image, x: 5, y: 5)
        XCTAssertGreaterThan(corner.0, 240)
        XCTAssertGreaterThan(corner.1, 240)
        XCTAssertGreaterThan(corner.2, 240)

        let center = pixel(image, x: 125, y: 75)
        XCTAssertGreaterThan(center.0, 200)
        XCTAssertLessThan(center.1, 60)
        XCTAssertLessThan(center.2, 60)
    }

    func testImageBackgroundFillsTheCanvas() async throws {
        let (directory, input) = try makePNG(
            color: NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1), width: 100, height: 100, name: "source.png"
        )
        let background = try makePNG(
            color: NSColor(srgbRed: 0, green: 0, blue: 1, alpha: 1), width: 200, height: 100, name: "background.png"
        ).1
        defer { try? FileManager.default.removeItem(at: directory) }

        let spec = ImageFrameSpec(
            paddingPercent: 0.2,
            cornerRadius: 0,
            shadow: false,
            background: .image(background),
            format: "png"
        )
        let outputs = try await ImageFrameEngine().run(
            Job(inputs: [input], operation: .imageFrame(spec))
        ) { _ in }

        let image = try load(outputs[0])
        XCTAssertEqual(image.width, 140)
        XCTAssertEqual(image.height, 140)

        let corner = pixel(image, x: 5, y: 5)
        XCTAssertLessThan(corner.0, 60)
        XCTAssertLessThan(corner.1, 60)
        XCTAssertGreaterThan(corner.2, 200)

        let center = pixel(image, x: 70, y: 70)
        XCTAssertGreaterThan(center.0, 200)
        XCTAssertLessThan(center.1, 60)
        XCTAssertLessThan(center.2, 60)
    }

    // MARK: Helpers

    private func makePNG(
        color: NSColor,
        width: Int,
        height: Int,
        name: String
    ) throws -> (URL, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)

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
        return (directory, url)
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
