import XCTest
import AppKit
import ImageIO
import UniformTypeIdentifiers
@testable import JobCore
@testable import ImageEngine

final class CropTests: XCTestCase {

    func testCropProducesRequestedPixelSize() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let input = directory.appendingPathComponent("source.png")
        try writeTestImage(width: 100, height: 80, to: input)

        let job = Job(
            inputs: [input],
            operation: .crop(CropSpec(x: 10, y: 5, width: 50, height: 40, format: "png"))
        )
        let outputs = try await ImageCropEngine().run(job) { _ in }

        XCTAssertEqual(outputs.count, 1)
        XCTAssertEqual(outputs[0].lastPathComponent, "source Cropped.png")

        let source = CGImageSourceCreateWithURL(outputs[0] as CFURL, nil)
        let image = try XCTUnwrap(source.flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) })
        XCTAssertEqual(image.width, 50)
        XCTAssertEqual(image.height, 40)
    }

    func testCropClampsToImageBounds() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let input = directory.appendingPathComponent("source.png")
        try writeTestImage(width: 40, height: 40, to: input)

        let job = Job(
            inputs: [input],
            operation: .crop(CropSpec(x: 30, y: 30, width: 50, height: 50, format: "png"))
        )
        let outputs = try await ImageCropEngine().run(job) { _ in }

        let source = CGImageSourceCreateWithURL(outputs[0] as CFURL, nil)
        let image = try XCTUnwrap(source.flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) })
        XCTAssertEqual(image.width, 10)
        XCTAssertEqual(image.height, 10)
    }

    private func writeTestImage(width: Int, height: Int, to url: URL) throws {
        let space = CGColorSpaceCreateDeviceRGB()
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(NSColor.systemOrange.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try XCTUnwrap(context.makeImage())

        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
}
