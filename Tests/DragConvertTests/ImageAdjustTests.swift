import XCTest
import AppKit
@testable import JobCore
@testable import ImageEngine

final class ImageAdjustTests: XCTestCase {

    func testBrightnessLiftsTheImage() throws {
        let image = try makeImage(color: NSColor(
            srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 1
        ))
        let output = try XCTUnwrap(ImageAdjustEngine.render(
            image,
            spec: ImageAdjustSpec(brightness: 0.3)
        ))
        let center = pixel(output, x: output.width / 2, y: output.height / 2)
        XCTAssertGreaterThan(center.0, 150)
    }

    func testFullDesaturationProducesGray() throws {
        let image = try makeImage(color: NSColor(
            srgbRed: 1, green: 0, blue: 0, alpha: 1
        ))
        let output = try XCTUnwrap(ImageAdjustEngine.render(
            image,
            spec: ImageAdjustSpec(saturation: -1)
        ))
        let center = pixel(output, x: output.width / 2, y: output.height / 2)
        let spread = max(center.0, center.1, center.2) - min(center.0, center.1, center.2)
        XCTAssertLessThan(spread, 10)
    }

    // MARK: Helpers

    private func makeImage(color: NSColor) throws -> CGImage {
        let context = try XCTUnwrap(CGContext(
            data: nil, width: 100, height: 100,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(color.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        return try XCTUnwrap(context.makeImage())
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
