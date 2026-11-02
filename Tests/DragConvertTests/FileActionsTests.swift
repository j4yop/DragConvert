import XCTest
@testable import JobCore

final class FileActionsTests: XCTestCase {

    func testCopyMoveAndSameFolderNoOp() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let source = root.appendingPathComponent("source")
        let destination = root.appendingPathComponent("destination")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let first = source.appendingPathComponent("a.txt")
        let second = source.appendingPathComponent("b.txt")
        try "one".write(to: first, atomically: true, encoding: .utf8)
        try "two".write(to: second, atomically: true, encoding: .utf8)

        let copied = try FileActions.transfer([first, second], to: destination, moving: false)
        XCTAssertEqual(copied.count, 2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.path))
        XCTAssertEqual(
            try String(contentsOf: destination.appendingPathComponent("a.txt"), encoding: .utf8),
            "one"
        )

        // Copying the same name again never overwrites.
        let again = try FileActions.transfer([first], to: destination, moving: false)
        XCTAssertEqual(again[0].lastPathComponent, "a 2.txt")

        let moving = source.appendingPathComponent("move.txt")
        try "three".write(to: moving, atomically: true, encoding: .utf8)
        let moved = try FileActions.transfer([moving], to: destination, moving: true)
        XCTAssertEqual(moved.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: moving.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: moved[0].path))

        // Moving into the folder it already lives in is a no-op.
        let noOp = try FileActions.transfer([first], to: source, moving: true)
        XCTAssertTrue(noOp.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.path))
    }
}
