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

public struct PDFSplitSpec: Equatable, Sendable {
    public enum Mode: String, Sendable {
        case atPages, equalParts
    }

    public var mode: Mode
    public var pages: [Int]
    public var parts: Int

    public init(mode: Mode, pages: [Int] = [], parts: Int = 2) {
        self.mode = mode
        self.pages = pages
        self.parts = parts
    }
}

public struct PDFPageEdit: Equatable, Sendable {
    public var sourceIndex: Int
    public var rotation: Int // extra quarter turns, 0...3

    public init(sourceIndex: Int, rotation: Int = 0) {
        self.sourceIndex = sourceIndex
        self.rotation = rotation
    }
}

public struct PDFOrganizeSpec: Equatable, Sendable {
    public var pages: [PDFPageEdit]

    public init(pages: [PDFPageEdit]) {
        self.pages = pages
    }
}

public struct PDFCompressSpec: Equatable, Sendable {
    public enum Mode: String, Sendable {
        case balanced, targetSize
    }

    public var mode: Mode
    public var targetBytes: Int

    public init(mode: Mode, targetBytes: Int = 500 * 1024) {
        self.mode = mode
        self.targetBytes = targetBytes
    }
}

public struct PDFCropSpec: Equatable, Sendable {
    /// Normalised crop box, top-left origin, 0...1 relative to the page's media box.
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct PDFRect: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct PDFPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct PDFColor: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

public struct PDFAnnotationSpec: Equatable, Sendable {
    public enum Kind: String, Sendable {
        case text, rectangle, ellipse, arrow, ink
    }

    public var kind: Kind
    public var pageIndex: Int
    public var rect: PDFRect
    public var points: [PDFPoint]
    public var text: String?
    public var color: PDFColor
    public var lineWidth: Double

    public init(
        kind: Kind,
        pageIndex: Int,
        rect: PDFRect = PDFRect(x: 0, y: 0, width: 0, height: 0),
        points: [PDFPoint] = [],
        text: String? = nil,
        color: PDFColor,
        lineWidth: Double = 2
    ) {
        self.kind = kind
        self.pageIndex = pageIndex
        self.rect = rect
        self.points = points
        self.text = text
        self.color = color
        self.lineWidth = lineWidth
    }
}

public struct PDFAnnotateSpec: Equatable, Sendable {
    public var annotations: [PDFAnnotationSpec]

    public init(annotations: [PDFAnnotationSpec]) {
        self.annotations = annotations
    }
}

public struct PDFRedaction: Equatable, Sendable {
    public var pageIndex: Int
    public var rect: PDFRect

    public init(pageIndex: Int, rect: PDFRect) {
        self.pageIndex = pageIndex
        self.rect = rect
    }
}

public struct PDFRedactSpec: Equatable, Sendable {
    public var redactions: [PDFRedaction]
    public var dpi: Int

    public init(redactions: [PDFRedaction], dpi: Int = 200) {
        self.redactions = redactions
        self.dpi = dpi
    }
}

public struct ImageColor: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

public struct ImageFrameSpec: Equatable, Sendable {
    public enum Background: Equatable, Sendable {
        case color(ImageColor)
        case image(URL)
    }

    public var paddingPercent: Double
    public var cornerRadius: Int
    public var shadow: Bool
    public var blurBackground: Bool
    public var background: Background
    public var format: String

    public init(
        paddingPercent: Double = 0.12,
        cornerRadius: Int = 24,
        shadow: Bool = true,
        blurBackground: Bool = false,
        background: Background = .color(ImageColor(red: 0.96, green: 0.94, blue: 0.90)),
        format: String = "png"
    ) {
        self.paddingPercent = paddingPercent
        self.cornerRadius = cornerRadius
        self.shadow = shadow
        self.blurBackground = blurBackground
        self.background = background
        self.format = format
    }
}

public struct ImageRedactSpec: Equatable, Sendable {
    public var redactions: [PDFRect]
    public var format: String

    public init(redactions: [PDFRect], format: String) {
        self.redactions = redactions
        self.format = format
    }
}

public struct ImageCropBatchSpec: Equatable, Sendable {
    public var normalized: PDFRect

    public init(normalized: PDFRect) {
        self.normalized = normalized
    }
}

public struct ImageCollageSpec: Equatable, Sendable {
    public enum Layout: String, Sendable {
        case grid, row, column, featured
    }

    public var layout: Layout
    public var columns: Int
    public var spacing: Int
    public var cornerRadius: Int
    public var background: ImageColor
    public var canvasWidth: Int
    public var format: String

    public init(
        layout: Layout = .grid,
        columns: Int = 2,
        spacing: Int = 16,
        cornerRadius: Int = 12,
        background: ImageColor = ImageColor(red: 1, green: 1, blue: 1),
        canvasWidth: Int = 1600,
        format: String = "png"
    ) {
        self.layout = layout
        self.columns = columns
        self.spacing = spacing
        self.cornerRadius = cornerRadius
        self.background = background
        self.canvasWidth = canvasWidth
        self.format = format
    }
}

public struct PDFFrameSpec: Equatable, Sendable {
    public enum Background: Equatable, Sendable {
        case color(ImageColor)
        case image(URL)
    }

    public var paddingPercent: Double
    public var shadow: Bool
    public var blurBackground: Bool
    public var background: Background
    public var dpi: Int

    public init(
        paddingPercent: Double = 0.12,
        shadow: Bool = true,
        blurBackground: Bool = false,
        background: Background = .color(ImageColor(red: 0.96, green: 0.94, blue: 0.90)),
        dpi: Int = 200
    ) {
        self.paddingPercent = paddingPercent
        self.shadow = shadow
        self.blurBackground = blurBackground
        self.background = background
        self.dpi = dpi
    }
}

public struct ImageAdjustSpec: Equatable, Sendable {
    public var brightness: Double
    public var contrast: Double
    public var saturation: Double
    public var warmth: Double
    public var format: String

    public init(
        brightness: Double = 0,
        contrast: Double = 0,
        saturation: Double = 0,
        warmth: Double = 0,
        format: String = "png"
    ) {
        self.brightness = brightness
        self.contrast = contrast
        self.saturation = saturation
        self.warmth = warmth
        self.format = format
    }
}

public struct ImageAnnotateSpec: Equatable, Sendable {
    public var annotations: [PDFAnnotationSpec]
    public var format: String

    public init(annotations: [PDFAnnotationSpec], format: String) {
        self.annotations = annotations
        self.format = format
    }
}

public enum JobOperation: Equatable, Sendable {
    case convert(to: String)
    case crop(CropSpec)
    case edit(ImageEditSpec)
    case compress(CompressSpec)
    case metadata(MetadataSpec)
    case pdfMerge
    case pdfSplit(PDFSplitSpec)
    case pdfOrganize(PDFOrganizeSpec)
    case pdfCompress(PDFCompressSpec)
    case pdfCrop(PDFCropSpec)
    case pdfFromImages
    case pdfAnnotate(PDFAnnotateSpec)
    case pdfRedact(PDFRedactSpec)
    case imageFrame(ImageFrameSpec)
    case imageRedact(ImageRedactSpec)
    case imageAnnotate(ImageAnnotateSpec)
    case imageCropBatch(ImageCropBatchSpec)
    case imageCollage(ImageCollageSpec)
    case imageRemoveBG
    case pdfFrame(PDFFrameSpec)
    case imageAdjust(ImageAdjustSpec)
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

public enum ConflictPolicy: String, Sendable, CaseIterable {
    case rename, replace
}

public enum DestinationPolicy {
    /// Read from Settings at launch. Default is the safe one.
    public static var policy: ConflictPolicy = .rename

    /// `Page 001.pdf` → `Page 001.jpg`; collision → `Page 001 2.jpg`.
    public static func outputURL(
        for input: URL,
        extension ext: String,
        exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) -> URL {
        let dir = input.deletingLastPathComponent()
        let base = input.deletingPathExtension().lastPathComponent
        let candidate = dir.appendingPathComponent("\(base).\(ext)")
        if policy == .replace { return candidate }
        return unique(candidate, exists: exists)
    }

    public static func unique(
        _ url: URL,
        exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) -> URL {
        if policy == .replace { return url }
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

    // Fail with the friendly permission error before an engine turns this
    // into an opaque "could not create a context / open a tmp file" message.
    guard FileManager.default.isWritableFile(atPath: dir.path) else {
        throw CocoaError(.fileWriteNoPermission)
    }

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
