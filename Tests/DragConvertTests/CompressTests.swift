import XCTest
import AppKit
import ImageIO
import UniformTypeIdentifiers
@testable import JobCore
@testable import ImageEngine

final class CompressTests: XCTestCase {

    func testTargetSizeIsRespected() async throws {
        let (directory, input) = try makeNoisyJPEG(width: 600, height: 400, quality: 0.95)
        defer { try? FileManager.default.removeItem(at: directory) }

        let target = 60 * 1024
        let spec = CompressSpec(
            mode: .targetSize,
            targetBytes: target,
            allowResize: true,
            format: "jpg"
        )
        let outputs = try await ImageCompressEngine().run(
            Job(inputs: [input], operation: .compress(spec))
        ) { _ in }

        XCTAssertEqual(outputs[0].lastPathComponent, "source Compressed.jpg")
        let size = try fileSize(outputs[0])
        XCTAssertLessThanOrEqual(size, target + 2048)
    }

    func testQualityModeProducesSmallerFile() async throws {
        let (directory, input) = try makeNoisyJPEG(width: 400, height: 300, quality: 0.95)
        defer { try? FileManager.default.removeItem(at: directory) }

        let low = CompressSpec(mode: .quality, quality: 0.3, format: "jpg")
        let high = CompressSpec(mode: .quality, quality: 0.9, format: "jpg")

        let lowOut = try await ImageCompressEngine().run(
            Job(inputs: [input], operation: .compress(low))
        ) { _ in }
        let highOut = try await ImageCompressEngine().run(
            Job(inputs: [input], operation: .compress(high))
        ) { _ in }

        XCTAssertLessThan(try fileSize(lowOut[0]), try fileSize(highOut[0]))
    }

    func testAlreadySmallerFileIsCopied() async throws {
        let (directory, input) = try makeNoisyJPEG(width: 120, height: 120, quality: 0.5)
        defer { try? FileManager.default.removeItem(at: directory) }

        let originalSize = try fileSize(input)
        let spec = CompressSpec(
            mode: .targetSize,
            targetBytes: 10 * 1024 * 1024,
            allowResize: false,
            format: "jpg"
        )
        let outputs = try await ImageCompressEngine().run(
            Job(inputs: [input], operation: .compress(spec))
        ) { _ in }

        XCTAssertEqual(try fileSize(outputs[0]), originalSize)
    }

    // MARK: Helpers

    private func makeNoisyJPEG(
        width: Int,
        height: Int,
        quality: Double
    ) throws -> (URL, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("source.jpg")

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for index in stride(from: 0, to: pixels.count, by: 4) {
            pixels[index] = UInt8.random(in: 0...255)
            pixels[index + 1] = UInt8.random(in: 0...255)
            pixels[index + 2] = UInt8.random(in: 0...255)
            pixels[index + 3] = 255
        }
        let provider = try XCTUnwrap(CGDataProvider(data: Data(pixels) as CFData))
        let image = try XCTUnwrap(CGImage(
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

        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(
            url as CFURL, UTType.jpeg.identifier as CFString, 1, nil
        ))
        CGImageDestinationAddImage(
            destination, image,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return (directory, url)
    }

    private func fileSize(_ url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return try XCTUnwrap((attributes[.size] as? NSNumber)?.intValue)
    }
}
