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
                let kbps = Self.bitrateKbps(for: target, input: input)
                arguments = ["-f", "m4af", "-d", "aac", "-b", "\(kbps * 1_000)"]
            case "wav", "aiff":
                arguments = [
                    "-f", target == "aiff" ? "AIFF" : "WAVE",
                    "-d", Self.pcmFormat(for: target)
                ]
            case "flac":
                // FLAC is lossless; a bitrate/depth control would be misleading.
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

    private static func bitrateKbps(for target: String, input: URL? = nil) -> Int {
        let raw = ConversionDefaults.audioBitrate(for: target)
        let number = Int(raw.split(separator: " ").first ?? "") ?? 256
        var kbps = min(max(number, 64), 320)
        // AAC rejects 320 kbps for mono at 44.1 kHz; 256 is the safe ceiling.
        if let input,
           let file = try? AVAudioFile(forReading: input),
           file.processingFormat.channelCount <= 1 {
            kbps = min(kbps, 256)
        }
        return kbps
    }

    private static func pcmFormat(for target: String) -> String {
        let depth = ConversionDefaults.audioDepth(for: target)
        let bigEndian = target == "aiff"
        switch depth {
        case "24": return bigEndian ? "BEI24" : "LEI24"
        case "32": return bigEndian ? "BEI32" : "LEI32"
        case "float32": return bigEndian ? "BEF32" : "LEF32"
        default: return bigEndian ? "BEI16" : "LEI16"
        }
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
        } else if target == "m4a" {
            try MediaProcess.write(to: output, extension: target) { temporary in
                let intermediate = temporary.deletingLastPathComponent()
                    .appendingPathComponent(".\(UUID().uuidString).m4a")
                defer { try? FileManager.default.removeItem(at: intermediate) }
                try MediaProcess.run("/usr/bin/avconvert", [
                    "--source", input.path,
                    "--preset", "PresetAppleM4A",
                    "--output", intermediate.path,
                    "--replace"
                ])
                let kbps = Self.bitrateKbps(for: "m4a")
                try MediaProcess.run("/usr/bin/afconvert", [
                    "-f", "m4af", "-d", "aac", "-b", "\(kbps * 1_000)",
                    intermediate.path, temporary.path
                ])
            }
        } else {
            try MediaProcess.write(to: output, extension: target) { temporary in
                try MediaProcess.run("/usr/bin/avconvert", [
                    "--source", input.path,
                    "--preset", Self.preset(for: target),
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
        let requestedFPS: Double
        switch ConversionDefaults.gifFrameRate(for: "gif") {
        case "30": requestedFPS = 30
        case "15": requestedFPS = 15
        default: requestedFPS = 10
        }
        let frameCount = max(1, min(300, Int(seconds * requestedFPS)))
        let framesPerSecond = Double(frameCount) / seconds

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        if let maxWidth = ConversionDefaults.gifMaxWidth(for: "gif") {
            generator.maximumSize = CGSize(
                width: CGFloat(maxWidth),
                height: CGFloat(maxWidth)
            )
        } else {
            generator.maximumSize = .zero
        }
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

    private static func preset(for target: String) -> String {
        let quality = ConversionDefaults.videoQuality(for: target)
        let compression = ConversionDefaults.videoCompression(for: target)
        var height = ConversionDefaults.videoMaxHeight(for: target)

        if height == nil {
            switch quality {
            case "smallerFile": height = 720
            case "higherQuality": height = nil
            default: height = 1080
            }
        }
        if compression == "strong", let current = height {
            height = min(current, 720)
        }

        switch height {
        case 2160: return "Preset3840x2160"
        case 1080: return "Preset1920x1080"
        case 720: return "Preset1280x720"
        case 480: return "Preset640x480"
        default: return "PresetHighestQuality"
        }
    }

    private static func bitrateKbps(for target: String) -> Int {
        let raw = ConversionDefaults.audioBitrate(for: target)
        let number = Int(raw.split(separator: " ").first ?? "") ?? 256
        return min(max(number, 64), 320)
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
