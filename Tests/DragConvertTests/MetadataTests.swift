import XCTest
import AppKit
import ImageIO
import UniformTypeIdentifiers
@testable import JobCore
@testable import ImageEngine

final class MetadataTests: XCTestCase {

    func testReadsCameraAndDates() throws {
        let (directory, input) = try makeTaggedJPEG()
        defer { try? FileManager.default.removeItem(at: directory) }

        let rows = ImageMetadata.rows(for: input)
        XCTAssertTrue(rows.contains { $0.group == "Camera" && $0.field == "Make" && $0.value == "Apple" })
        XCTAssertTrue(rows.contains { $0.group == "Camera" && $0.field == "Model" && $0.value == "iPhone 15 Pro" })
        XCTAssertTrue(rows.contains { $0.group == "Dates" && $0.field == "Taken" })
    }

    func testParsesGPSFromProperties() {
        let properties: [CFString: Any] = [
            kCGImagePropertyGPSDictionary: [
                "Latitude": [
                    NSNumber(value: 12.0), NSNumber(value: 58.0), NSNumber(value: 18.0)
                ],
                "LatitudeRef": "N",
                "Longitude": [
                    NSNumber(value: 77.0), NSNumber(value: 35.0), NSNumber(value: 0.0)
                ],
                "LongitudeRef": "E"
            ]
        ]
        let rows = ImageMetadata.rows(
            properties: properties,
            url: URL(fileURLWithPath: "/tmp/test.jpg")
        )
        XCTAssertTrue(rows.contains { $0.group == "Location" && $0.field == "Latitude" })
        XCTAssertTrue(rows.contains { $0.group == "Location" && $0.field == "Longitude" })
        XCTAssertTrue(ImageMetadata.hasLocation(rows))
    }

    func testStripRemovesCameraMetadata() async throws {
        let (directory, input) = try makeTaggedJPEG()
        defer { try? FileManager.default.removeItem(at: directory) }

        let before = try dimensions(input)
        let spec = MetadataSpec(action: .strip, format: "jpg")
        let outputs = try await ImageMetadataEngine().run(
            Job(inputs: [input], operation: .metadata(spec))
        ) { _ in }

        XCTAssertEqual(outputs[0].lastPathComponent, "source Clean.jpg")
        let after = try dimensions(outputs[0])
        XCTAssertEqual(before.width, after.width)
        XCTAssertEqual(before.height, after.height)

        let cleanRows = ImageMetadata.rows(for: outputs[0])
        XCTAssertFalse(cleanRows.contains { $0.group == "Camera" })
    }

    // MARK: Helpers

    private func makeTaggedJPEG() throws -> (URL, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("source.jpg")

        let context = try XCTUnwrap(CGContext(
            data: nil, width: 240, height: 180,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(NSColor.systemOrange.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 240, height: 180))
        let image = try XCTUnwrap(context.makeImage())

        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(
            url as CFURL, UTType.jpeg.identifier as CFString, 1, nil
        ))
        let exif: [CFString: Any] = [
            kCGImagePropertyExifDateTimeOriginal: "2024:10:13 19:25:00",
            kCGImagePropertyExifLensModel: "Test Lens",
            kCGImagePropertyExifFNumber: 2.8,
            kCGImagePropertyExifISOSpeedRatings: [100]
        ]
        let tiff: [CFString: Any] = [
            kCGImagePropertyTIFFMake: "Apple",
            kCGImagePropertyTIFFModel: "iPhone 15 Pro"
        ]
        let properties: [CFString: Any] = [
            kCGImagePropertyExifDictionary: exif,
            kCGImagePropertyTIFFDictionary: tiff
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return (directory, url)
    }

    private func dimensions(_ url: URL) throws -> (width: Int, height: Int) {
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        let image = try XCTUnwrap(source.flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) })
        return (image.width, image.height)
    }
}
