import Foundation
import JobCore
import EngineKit

struct ArchiveEngine: Engine {
    let id = "archive.convert"

    func canHandle(_ job: Job) -> Bool {
        guard case .convert(let ext) = job.operation,
              ["zip", "tar", "gz"].contains(ext.lowercased()),
              let input = job.inputs.first else { return false }
        return ["zip", "tar", "gz"].contains(input.pathExtension.lowercased())
    }

    func run(
        _ job: Job,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> [URL] {
        guard let input = job.inputs.first,
              case .convert(let ext) = job.operation else {
            throw EngineError.corruptInput("archive")
        }
        let work = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }

        try Self.extract(input, to: work)
        let output = DestinationPolicy.outputURL(for: input, extension: ext)
        try writeAtomically(to: output) { tmp in
            try Self.archive(work, to: tmp, format: ext)
        }
        progress(1)
        return [output]
    }

    /// Extracts an archive beside itself into a new folder and returns that
    /// folder. Supports ZIP, TAR, GZIP, RAR and 7-Zip through the system
    /// libarchive-backed `bsdtar`; RAR creation is deliberately not offered.
    static func extractArchive(_ input: URL) throws -> URL {
        let destination = extractionDestination(for: input)
        try FileManager.default.createDirectory(
            at: destination,
            withIntermediateDirectories: true
        )
        do {
            try extract(input, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
        return destination
    }

    static func extractionDestination(for input: URL) -> URL {
        let directory = input.deletingLastPathComponent()
        let base = input.deletingPathExtension().lastPathComponent
        var candidate = directory.appendingPathComponent(base, isDirectory: true)
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(base) \(index)", isDirectory: true)
            index += 1
        }
        return candidate
    }

    private static func extract(_ input: URL, to directory: URL) throws {
        switch input.pathExtension.lowercased() {
        case "zip":
            try validateEntries(input)
            try run("/usr/bin/ditto", ["-x", "-k", input.path, directory.path])
        case "tar":
            try validateEntries(input)
            try run("/usr/bin/tar", ["-xf", input.path, "-C", directory.path])
        case "gz":
            let data = try pipe("/usr/bin/gzip", ["-dc", input.path])
            let name = input.deletingPathExtension().lastPathComponent
            let file = directory.appendingPathComponent(name)
            try data.write(to: file)
            if name.lowercased().hasSuffix(".tar") {
                try run("/usr/bin/tar", ["-xf", file.path, "-C", directory.path])
                try? FileManager.default.removeItem(at: file)
            }
        case "rar", "7z":
            try validateEntries(input)
            try run(
                "/usr/bin/bsdtar",
                ["-xf", input.path, "-C", directory.path, "--no-same-owner"]
            )
        default:
            throw EngineError.unsupported(input.pathExtension)
        }
    }

    /// Reject absolute and parent-relative entries before extracting. libarchive
    /// usually blocks these itself, but a failed preflight gives a clear error.
    private static func validateEntries(_ input: URL) throws {
        let listing = try pipe("/usr/bin/bsdtar", ["-tf", input.path])
        guard let text = String(data: listing, encoding: .utf8) else {
            throw EngineError.corruptInput(input.lastPathComponent)
        }
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let path = String(line)
            if path.hasPrefix("/") || path.split(separator: "/").contains("..") {
                throw EngineError.corruptInput(
                    "\(input.lastPathComponent) contains an unsafe path"
                )
            }
        }
    }

    private static func archive(_ directory: URL, to output: URL, format: String) throws {
        switch format.lowercased() {
        case "zip":
            try run("/usr/bin/zip", ["-r", "-q", output.path, "."], cwd: directory)
        case "tar":
            try run("/usr/bin/tar", ["-cf", output.path, "-C", directory.path, "."])
        case "gz":
            let tar = directory.deletingLastPathComponent()
                .appendingPathComponent(UUID().uuidString + ".tar")
            defer { try? FileManager.default.removeItem(at: tar) }
            try run("/usr/bin/tar", ["-cf", tar.path, "-C", directory.path, "."])
            let data = try pipe("/usr/bin/gzip", ["-c", tar.path])
            try data.write(to: output)
        default:
            throw EngineError.unsupported(format)
        }
    }

    private static func run(_ tool: String, _ arguments: [String], cwd: URL? = nil) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        if let cwd { process.currentDirectoryURL = cwd }
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw EngineError.writeFailed("\(tool) failed")
        }
    }

    private static func pipe(_ tool: String, _ arguments: [String]) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw EngineError.writeFailed("\(tool) failed")
        }
        return data
    }
}
