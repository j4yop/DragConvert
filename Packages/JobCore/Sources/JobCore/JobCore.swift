import Foundation

public struct CropSpec: Equatable, Sendable {
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int
    public let format: String

    public init(x: Int, y: Int, width: Int, height: Int, format: String) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.format = format
    }
}

public struct ImageEditSpec: Equatable, Sendable {
    public var width: Int
    public var height: Int
    public var quarterTurns: Int
    public var flipHorizontal: Bool
    public var flipVertical: Bool
    public var format: String
    public var suffix: String

    public init(
        width: Int,
        height: Int,
        quarterTurns: Int = 0,
        flipHorizontal: Bool = false,
        flipVertical: Bool = false,
        format: String,
        suffix: String
    ) {
        self.width = width
        self.height = height
        self.quarterTurns = quarterTurns
        self.flipHorizontal = flipHorizontal
        self.flipVertical = flipVertical
        self.format = format
        self.suffix = suffix
    }
}

public struct CompressSpec: Equatable, Sendable {
    public enum Mode: String, Sendable {
        case targetSize, quality
    }

    public var mode: Mode
    public var targetBytes: Int
    public var quality: Double
    public var allowResize: Bool
    public var format: String

    public init(
        mode: Mode,
        targetBytes: Int = 500 * 1024,
        quality: Double = 0.75,
        allowResize: Bool = true,
        format: String
    ) {
        self.mode = mode
        self.targetBytes = targetBytes
        self.quality = quality
        self.allowResize = allowResize
        self.format = format
    }
}

public struct MetadataSpec: Equatable, Sendable {
    public enum Action: String, Sendable {
        case strip
    }

    public var action: Action
    public var format: String

    public init(action: Action, format: String) {
        self.action = action
        self.format = format
    }
}

public enum JobOperation: Equatable, Sendable {
    case convert(to: String)
    case crop(CropSpec)
    case edit(ImageEditSpec)
    case compress(CompressSpec)
    case metadata(MetadataSpec)
    case tool(id: String)
}

public struct Job: Identifiable, Sendable {
    public let id: UUID
    public let inputs: [URL]
    public let operation: JobOperation
    public let outputDirectory: URL

    public init(
        id: UUID = UUID(),
        inputs: [URL],
        operation: JobOperation,
        outputDirectory: URL? = nil
    ) {
        self.id = id
        self.inputs = inputs
        self.operation = operation
        self.outputDirectory = outputDirectory
            ?? inputs.first?.deletingLastPathComponent()
            ?? FileManager.default.homeDirectoryForCurrentUser
    }
}

public enum JobEvent: Sendable {
    case started(Job.ID)
    case progress(Job.ID, Double)
    case finished(Job.ID, [URL])
    case failed(Job.ID, String)
    case cancelled(Job.ID)
}

public enum DestinationPolicy {
    /// `Page 001.pdf` → `Page 001.jpg`; collision → `Page 001 2.jpg`.
    public static func outputURL(
        for input: URL,
        extension ext: String,
        exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) -> URL {
        let dir = input.deletingLastPathComponent()
        let base = input.deletingPathExtension().lastPathComponent
        return unique(dir.appendingPathComponent("\(base).\(ext)"), exists: exists)
    }

    public static func unique(
        _ url: URL,
        exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) -> URL {
        guard exists(url) else { return url }
        let dir = url.deletingLastPathComponent()
        let ext = url.pathExtension
        let base = url.deletingPathExtension().lastPathComponent
        var index = 2
        while true {
            let candidate = dir.appendingPathComponent("\(base) \(index).\(ext)")
            if !exists(candidate) { return candidate }
            index += 1
        }
    }
}

/// Write to a hidden temp file in the destination folder, then rename.
public func writeAtomically(to destination: URL, _ body: (URL) throws -> Void) throws {
    let dir = destination.deletingLastPathComponent()
    let tmp = dir.appendingPathComponent(".\(UUID().uuidString).tmp")
    do {
        try body(tmp)
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: tmp)
        } else {
            try FileManager.default.moveItem(at: tmp, to: destination)
        }
    } catch {
        try? FileManager.default.removeItem(at: tmp)
        throw error
    }
}

public actor JobQueue {
    public typealias Executor = @Sendable (Job, @Sendable @escaping (Double) -> Void) async throws -> [URL]

    public let events: AsyncStream<JobEvent>

    private let limit: Int
    private let executor: Executor
    private let continuation: AsyncStream<JobEvent>.Continuation
    private var running = 0
    private var pending: [Job] = []

    public init(limit: Int = 2, executor: @escaping Executor) {
        self.limit = max(1, limit)
        self.executor = executor
        let (stream, cont) = AsyncStream<JobEvent>.makeStream()
        self.events = stream
        self.continuation = cont
    }

    public func enqueue(_ job: Job) {
        pending.append(job)
        pump()
    }

    private func pump() {
        while running < limit, !pending.isEmpty {
            let job = pending.removeFirst()
            running += 1
            continuation.yield(.started(job.id))

            let executor = self.executor
            let continuation = self.continuation

            Task.detached(priority: .userInitiated) { [weak self] in
                do {
                    let outputs = try await executor(job) { value in
                        continuation.yield(.progress(job.id, value))
                    }
                    if Task.isCancelled {
                        continuation.yield(.cancelled(job.id))
                    } else {
                        continuation.yield(.finished(job.id, outputs))
                    }
                } catch is CancellationError {
                    continuation.yield(.cancelled(job.id))
                } catch {
                    continuation.yield(.failed(job.id, error.localizedDescription))
                }
                await self?.jobDone()
            }
        }
    }

    private func jobDone() {
        running = max(0, running - 1)
        pump()
    }
}
