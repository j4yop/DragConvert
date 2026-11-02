import XCTest
import AppKit
import CoreImage
import ImageIO
@testable import ImageEngine

final class QRCodeTests: XCTestCase {

    func testDecodesAGeneratedQRCode() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("qr.png")
        let payload = "https://example.com/dragconvert"

        let filter = try XCTUnwrap(CIFilter(name: "CIQRCodeGenerator"))
        filter.setValue(Data(payload.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        let output = try XCTUnwrap(filter.outputImage)
            .transformed(by: CGAffineTransform(scaleX: 12, y: 12))

        let context = CIContext()
        let image = try XCTUnwrap(context.createCGImage(output, from: output.extent))
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(
            url as CFURL, "public.png" as CFString, 1, nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))

        let values = QRCodeReader.decode(at: url)
        XCTAssertTrue(values.contains(payload))
    }
}
