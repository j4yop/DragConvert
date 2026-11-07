import XCTest
import AVFoundation
@testable import JobCore
@testable import MediaEngine

final class MediaEngineTests: XCTestCase {

    func testWAVToM4A() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let input = directory.appendingPathComponent("tone.wav")
        try makeTone(to: input)

        let engine = AudioEngine()
        XCTAssertTrue(
            engine.canHandle(Job(inputs: [input], operation: .convert(to: "m4a")))
        )
        XCTAssertFalse(
            engine.canHandle(Job(inputs: [input], operation: .convert(to: "mp3")))
        )

        let output = try await engine.run(
            Job(inputs: [input], operation: .convert(to: "m4a"))
        ) { _ in }[0]

        let audio = try AVAudioFile(forReading: output)
        XCTAssertGreaterThan(audio.length, 0)
        XCTAssertGreaterThan(audio.processingFormat.sampleRate, 8_000)
    }

    func testAudioBitrateSettingChangesOutputSize() async throws {
        let key = "conversionProfile.m4a.audioBitrate"
        let previous = UserDefaults.standard.string(forKey: key)
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appendingPathComponent("tone.wav")
        try makeTone(to: input)

        let engine = AudioEngine()
        UserDefaults.standard.set("128 kbps", forKey: key)
        let small = try await engine.run(
            Job(inputs: [input], operation: .convert(to: "m4a"))
        ) { _ in }[0]

        UserDefaults.standard.set("320 kbps", forKey: key)
        let large = try await engine.run(
            Job(inputs: [input], operation: .convert(to: "m4a"))
        ) { _ in }[0]

        let smallSize = try FileManager.default
            .attributesOfItem(atPath: small.path)[.size] as? NSNumber
        let largeSize = try FileManager.default
            .attributesOfItem(atPath: large.path)[.size] as? NSNumber
        XCTAssertGreaterThan(
            largeSize?.intValue ?? 0,
            smallSize?.intValue ?? 0,
            "320 kbps should be larger than 128 kbps"
        )
    }

    private func makeTone(to url: URL) throws {
        let sampleRate = 44_100
        let seconds = 1
        let frames = sampleRate * seconds
        var data = Data()

        func append<T: FixedWidthInteger>(_ value: T) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }

        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36 + frames * 2))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        append(UInt32(16))
        append(UInt16(1))
        append(UInt16(1))
        append(UInt32(sampleRate))
        append(UInt32(sampleRate * 2))
        append(UInt16(2))
        append(UInt16(16))
        data.append(contentsOf: Array("data".utf8))
        append(UInt32(frames * 2))

        for index in 0..<frames {
            let value = sin(2 * Double.pi * 440 * Double(index) / Double(sampleRate))
            append(Int16(value * 12_000))
        }
        try data.write(to: url)
    }
}
