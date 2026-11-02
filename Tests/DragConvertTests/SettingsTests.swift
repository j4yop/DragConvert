import XCTest
import AppKit
@testable import CapabilityGraph
@testable import JobCore

final class SettingsTests: XCTestCase {

    func testCustomWheelShortcut() {
        let original = WheelShortcuts.convert
        defer { WheelShortcuts.convert = original }

        WheelShortcuts.convert = .command
        XCTAssertEqual(WheelMode.from(.command), .convert)
        XCTAssertNil(WheelMode.from(.option))
    }

    func testReplacePolicyKeepsTheSameName() {
        let original = DestinationPolicy.policy
        defer { DestinationPolicy.policy = original }

        DestinationPolicy.policy = .replace
        let input = URL(fileURLWithPath: "/tmp/Page 001.pdf")
        let output = DestinationPolicy.outputURL(for: input, extension: "jpg") { _ in true }
        XCTAssertEqual(output.lastPathComponent, "Page 001.jpg")
    }
}
