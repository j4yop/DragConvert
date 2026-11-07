import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers
import JobCore
import EngineKit

// MARK: - Audio

/// Audio conversion through the system `afconvert` tool. Apple's encoders
/// cover M4A/AAC, WAV, AIFF and FLAC; MP3, Vorbis and WMA encoding is not
/// available in macOS itself, so those targets are never offered.
public struct AudioEngine: Engine {
    public let id = "audio.convert"

    private static let sources: Set<String> = [
        "mp3", "m4a", "wav", "flac", "opus", "aiff", "aif", "caf"
    ]
    private static let targets: Set<String> = ["m4a", "wav", "aiff", "flac"]

    public init() {}

    public func canHandle(_ job: Job) -> Bool {
        guard case .convert(let target) = job.operation,
              let input = job.inputs.first else { return false }
        return Self.sources.contains(input.pathExtension.lowercased())
            && Self.targets.contains(target.lowercased())
    }

    public func run(
        _ job: Job,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> [URL] {
        guard let input = job.inputs.first,
              case .convert(let targetRaw) = job.operation else {
            throw EngineError.corruptInput("(missing audio)")
        }
        let target = targetRaw.lowercased()
        guard Self.targets.contains(target) else {
            throw EngineError.unsupported("audio → \(target)")
        }

        let output = DestinationPolicy.outputURL(for: input, extension: target)
        progress(0.05)

        try MediaProcess.write(to: output, extension: target) { temporary in
            var arguments: [String] = []
            switch target {
            case "m4a":
                arguments = ["-f", "m4af", "-d", "aac", "-b", "192000"]
            case "wav":
                arguments = ["-f", "WAVE", "-d", "LEI16"]
            case "aiff":
                arguments = ["-f", "AIFF", "-d", "BEI16"]
            case "flac":
                arguments = ["-f", "flac", "-d", "flac"]
            default:
                throw EngineError.unsupported("audio → \(target)")
            }
            arguments.append(contentsOf: [input.path, temporary.path])
            try MediaProcess.run("/usr/bin/afconvert", arguments)
        }

        progress(1)
        return [output]
    }
}

// MARK: - Video

/// Video conversion through the system `avconvert` tool, plus a native
/// AVFoundation frame grabber for GIF output. Inputs are limited to the
/// containers macOS can actually read (MP4/MOV/M4V).
public struct VideoEngine: Engine {
    public let id = "video.convert"

    private static let sources: Set<String> = ["mp4", "mov", "m4v"]
    private static let targets: Set<String> = ["mp4", "mov", "m4v", "m4a", "gif"]

    public init() {}

    public func canHandle(_ job: Job) -> Bool {
        guard case .convert(let target) = job.operation,
              let input = job.inputs.first else { return false }
        return Self.sources.contains(input.pathExtension.lowercased())
            && Self.targets.contains(target.lowercased())
    }

    public func run(
        _ job: Job,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> [URL] {
        guard let input = job.inputs.first,
              case .convert(let targetRaw) = job.operation else {
            throw EngineError.corruptInput("(missing video)")
        }
        let target = targetRaw.lowercased()
        guard Self.targets.contains(target) else {
            throw EngineError.unsupported("video → \(target)")
        }

        let output = DestinationPolicy.outputURL(for: input, extension: target)
        progress(0.05)

        if target == "gif" {
            try await makeGIF(input: input, output: output, progress: progress)
        } else {
            try MediaProcess.write(to: output, extension: target) { temporary in
                let preset = target == "m4a"
                    ? "PresetAppleM4A"
                    : "PresetHighestQuality"
                try MediaProcess.run("/usr/bin/avconvert", [
                    "--source", input.path,
                    "--preset", preset,
                    "--output", temporary.path,
                    "--replace"
                ])
            }
        }

        progress(1)
        return [output]
    }

    private func makeGIF(
        input: URL,
        output: URL,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws {
        let asset = AVURLAsset(url: input)
        let duration = try await asset.load(.duration)
        let seconds = max(0.1, duration.seconds)
        let framesPerSecond = 10.0
        let frameCount = max(1, min(240, Int(seconds * framesPerSecond)))

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 640)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        try MediaProcess.write(to: output, extension: "gif") { temporary in
            guard let destination = CGImageDestinationCreateWithURL(
                temporary as CFURL,
                UTType.gif.identifier as CFString,
                frameCount,
                nil
            ) else {
                throw EngineError.writeFailed("could not create a GIF")
            }

            let fileProperties: CFDictionary = [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFLoopCount: 0
                ]
            ] as CFDictionary
            CGImageDestinationSetProperties(destination, fileProperties)

            let delay = 1.0 / framesPerSecond
            for index in 0..<frameCount {
                if Task.isCancelled { throw CancellationError() }
                let time = CMTime(
                    seconds: min(seconds - 0.01, Double(index) / framesPerSecond),
                    preferredTimescale: 600
                )
                do {
                    let image = try generator.copyCGImage(at: time, actualTime: nil)
                    let frameProperties: CFDictionary = [
                        kCGImagePropertyGIFDictionary: [
                            kCGImagePropertyGIFDelayTime: delay,
                            kCGImagePropertyGIFUnclampedDelayTime: delay
                        ]
                    ] as CFDictionary
                    CGImageDestinationAddImage(destination, image, frameProperties)
                } catch {
                    // A frame at the exact end can fail; keep the frames we have.
                    if index == 0 { throw error }
                }
                progress(Double(index + 1) / Double(frameCount) * 0.95)
            }

            guard CGImageDestinationFinalize(destination) else {
                throw EngineError.writeFailed("the GIF encoder rejected the frames")
            }
        }
    }
}

// MARK: - Process helper

private enum MediaProcess {
    static func run(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments

        let errors = Pipe()
        process.standardError = errors
        process.standardOutput = Pipe()

        do {
            try process.run()
        } catch {
            throw EngineError.writeFailed("could not launch \(tool)")
        }
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = errors.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw EngineError.writeFailed(
                message?.isEmpty == false
                    ? message!
                    : "\(tool) could not convert this file"
            )
        }
    }

    /// Writes beside the destination with the real extension (avconvert needs
    /// it), then moves the finished file into place atomically.
    static func write(
        to output: URL,
        extension ext: String,
        _ body: (URL) throws -> Void
    ) throws {
        let directory = output.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: directory.path) else {
            throw CocoaError(.fileWriteNoPermission)
        }
        let temporary = directory.appendingPathComponent(
            ".\(UUID().uuidString).\(ext)"
        )
        defer { try? FileManager.default.removeItem(at: temporary) }

        try body(temporary)
        guard FileManager.default.fileExists(atPath: temporary.path) else {
            throw EngineError.writeFailed("the converter produced no output")
        }
        if FileManager.default.fileExists(atPath: output.path) {
            try FileManager.default.removeItem(at: output)
        }
        try FileManager.default.moveItem(at: temporary, to: output)
    }
}
