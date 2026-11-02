import XCTest
import AppKit
@testable import CapabilityGraph
@testable import JobCore
@testable import ImageEngine

final class CapabilityTests: XCTestCase {

    func testDetectsAllNineFamilies() {
        let cases: [(String, FileKind)] = [
            ("a.pdf", .pdf),
            ("a.heic", .image),
            ("a.svg", .image),
            ("a.docx", .document),
            ("a.pages", .document),
            ("a.pptx", .slides),
            ("a.ppt", .slides),
            ("a.xlsx", .spreadsheet),
            ("a.csv", .spreadsheet),
            ("a.mp3", .audio),
            ("a.flac", .audio),
            ("a.mp4", .video),
            ("a.mkv", .video),
            ("a.gif", .video),
            ("a.rtfd", .document),
            ("a.textClipping", .document),
            ("a.srt", .subtitle),
            ("a.zip", .archive),
            ("a.unknownext", .unknown)
        ]
        for (name, expected) in cases {
            XCTAssertEqual(FileKind.detect(URL(fileURLWithPath: "/tmp/\(name)")), expected, name)
        }
    }

    func testMixedSelectionHasNoCommonKind() {
        let urls = [URL(fileURLWithPath: "/tmp/a.pdf"), URL(fileURLWithPath: "/tmp/a.png")]
        XCTAssertNil(FileKind.commonKind(of: urls))
        XCTAssertEqual(FileKind.commonKind(of: [URL(fileURLWithPath: "/tmp/a.pdf"),
                                              URL(fileURLWithPath: "/tmp/b.pdf")]), .pdf)
    }

    func testOwnFormatNeverAppears() {
        let items = Capabilities.items(mode: .convert, kind: .image, inputExtension: "png")
        XCTAssertFalse(items.contains { $0.id == "convert:png" })
        XCTAssertTrue(items.contains { $0.id == "convert:jpg" })
    }

    func testWheelNeverExceedsTenWedges() {
        for kind in FileKind.allCases {
            XCTAssertLessThanOrEqual(
                Capabilities.items(mode: .convert, kind: kind).count,
                Capabilities.maxWedges, "\(kind)"
            )
            XCTAssertLessThanOrEqual(
                Capabilities.items(mode: .tools, kind: kind).count,
                Capabilities.maxWedges, "\(kind)"
            )
        }
    }

    func testActionsWheelHasSixItems() {
        let items = Capabilities.items(mode: .actions, kind: .pdf)
        XCTAssertEqual(items.count, 6)
        XCTAssertEqual(items.map(\.id), [
            "action:airdrop", "action:float", "action:copy",
            "action:move", "action:copypath", "action:terminal"
        ])
    }

    func testModifierRouting() {
        XCTAssertEqual(WheelMode.from(.shift), .convert)
        XCTAssertEqual(WheelMode.from([.option, .shift]), .tools)
        XCTAssertEqual(WheelMode.from(.control), .actions)
        XCTAssertEqual(WheelMode.from([.control, .shift]), .actions)
        XCTAssertNil(WheelMode.from([]))
    }

    func testSVGIsNotAdvertisedUntilResvgShips() {
        let svg = URL(fileURLWithPath: "/tmp/vector.svg")
        let job = Job(inputs: [svg], operation: .convert(to: "png"))
        XCTAssertFalse(ImageConvertEngine().canHandle(job))
    }

    func testWheelStaysOpenAfterModifierRelease() {
        var tracker = WheelModeTracker()
        XCTAssertEqual(tracker.update(modifiers: .shift), .convert)
        XCTAssertEqual(tracker.update(modifiers: []), .convert)
        XCTAssertEqual(tracker.update(modifiers: [.option, .shift]), .tools)
        XCTAssertEqual(tracker.update(modifiers: []), .tools)
        tracker.reset()
        XCTAssertNil(tracker.update(modifiers: []))
    }

    func testSingleFileHidesMergeAndCollage() {
        XCTAssertFalse(Capabilities.tools(.image, fileCount: 1).contains { $0.id == "tool:collage" })
        XCTAssertFalse(Capabilities.tools(.pdf, fileCount: 1).contains { $0.id == "tool:merge" })
    }

    func testMixedImagesShareCommonTargets() {
        let items = Capabilities.convertItems(
            kinds: [.image, .image],
            inputExtensions: ["heic", "png"]
        )
        XCTAssertTrue(items.contains { $0.id == "convert:jpg" })
        XCTAssertFalse(items.contains { $0.id == "convert:docx" })
    }

    func testMixedImageAndPDFUseTheIntersection() {
        let items = Capabilities.convertItems(
            kinds: [.image, .pdf],
            inputExtensions: ["png", "pdf"]
        )
        XCTAssertEqual(items.map(\.id), ["convert:jpg", "convert:png", "convert:tiff"])
    }

    func testMultiFileToolsAreTruthful() {
        XCTAssertEqual(
            Set(Capabilities.tools(.image, fileCount: 2).map(\.id)),
            ["tool:crop", "tool:collage"]
        )
        XCTAssertEqual(
            Capabilities.tools(.pdf, fileCount: 2).map(\.id),
            ["tool:merge"]
        )
        XCTAssertTrue(Capabilities.tools(.video, fileCount: 2).isEmpty)
    }

    func testCollisionNaming() {
        let input = URL(fileURLWithPath: "/tmp/Page 001.pdf")
        let taken = Set(["/tmp/Page 001.jpg", "/tmp/Page 001 2.jpg"])
        let out = DestinationPolicy.outputURL(for: input, extension: "jpg") { taken.contains($0.path) }
        XCTAssertEqual(out.path, "/tmp/Page 001 3.jpg")
    }

    func testAtomicWriteLeavesNoTempFile() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let target = dir.appendingPathComponent("result.txt")
        try writeAtomically(to: target) { tmp in
            try "hello".write(to: tmp, atomically: true, encoding: .utf8)
        }
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "hello")
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasSuffix(".tmp") }
        XCTAssertTrue(leftovers.isEmpty)
    }
}
