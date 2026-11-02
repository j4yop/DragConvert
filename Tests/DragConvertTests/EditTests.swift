import XCTest
import AppKit
import ImageIO
import UniformTypeIdentifiers
@testable import JobCore
@testable import ImageEngine

final class EditTests: XCTestCase {

    func testResizeProducesRequestedSize() async throws {
        let (directory, input) = try makeInput(width: 100, height: 80)
        defer { try? FileManager.default.removeItem(at: directory) }

        let spec = ImageEditSpec(
            width: 50, height: 40, format: "png", suffix: "Resized"
        )
        let outputs = try await ImageEditEngine().run(
            Job(inputs: [input], operation: .edit(spec))
        ) { _ in }

        XCTAssertEqual(outputs[0].lastPathComponent, "source Resized.png")
        let image = try load(outputs[0])
        XCTAssertEqual(image.width, 50)
        XCTAssertEqual(image.height, 40)
    }

    func testRotate90SwapsDimensions() async throws {
        let (directory, input) = try makeInput(width: 100, height: 80)
        defer { try? FileManager.default.removeItem(at: directory) }

        let spec = ImageEditSpec(
            width: 80, height: 100, quarterTurns: 1,
            format: "png", suffix: "Rotated"
        )
        let outputs = try await ImageEditEngine().run(
            Job(inputs: [input], operation: .edit(spec))
        ) { _ in }

        XCTAssertEqual(outputs[0].lastPathComponent, "source Rotated.png")
        let image = try load(outputs[0])
        XCTAssertEqual(image.width, 80)
        XCTAssertEqual(image.height, 100)
    }

    func testRotate180KeepsDimensions() async throws {
        let (directory, input) = try makeInput(width: 100, height: 80)
        defer { try? FileManager.default.removeItem(at: directory) }

        let spec = ImageEditSpec(
            width: 100, height: 80, quarterTurns: 2,
            format: "png", suffix: "Rotated"
        )
        let outputs = try await ImageEditEngine().run(
            Job(inputs: [input], operation: .edit(spec))
        ) { _ in }

        let image = try load(outputs[0])
        XCTAssertEqual(image.width, 100)
        XCTAssertEqual(image.height, 80)
    }

    func testFlipKeepsDimensions() async throws {
        let (directory, input) = try makeInput(width: 60, height: 40)
        defer { try? FileManager.default.removeItem(at: directory) }

        let spec = ImageEditSpec(
            width: 60, height: 40, flipHorizontal: true,
            format: "png", suffix: "Edited"
        )
        let outputs = try await ImageEditEngine().run(
            Job(inputs: [input], operation: .edit(spec))
        ) { _ in }

        XCTAssertEqual(outputs[0].lastPathComponent, "source Edited.png")
        let image = try load(outputs[0])
        XCTAssertEqual(image.width, 60)
        XCTAssertEqual(image.height, 40)
    }

    // MARK: Helpers

    private func makeInput(width: Int, height: Int) throws -> (URL, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let input = directory.appendingPathComponent("source.png")

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
            input as CFURL, UTType.png.identifier as CFString, 1, nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return (directory, input)
    }

    private func load(_ url: URL) throws -> CGImage {
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        return try XCTUnwrap(source.flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) })
    }
}
