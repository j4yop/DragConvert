import Foundation
import PDFKit
import JobCore
import EngineKit

public struct PDFSplitEngine: Engine {
    public let id = "pdf.split"

    public init() {}

    public func canHandle(_ job: Job) -> Bool {
        if case .pdfSplit = job.operation { return true }
        return false
    }

    public func run(
        _ job: Job,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> [URL] {
        guard let input = job.inputs.first else {
            throw EngineError.corruptInput("(missing file)")
        }
        guard case .pdfSplit(let spec) = job.operation else {
            throw EngineError.unsupported("\(job.operation)")
        }
        guard let document = PDFDocument(url: input), document.pageCount > 0 else {
            throw EngineError.corruptInput(input.lastPathComponent)
        }

        let ranges = Self.ranges(spec, pageCount: document.pageCount)
        guard !ranges.isEmpty else {
            throw EngineError.unsupported("No valid split points")
        }

        let base = input.deletingPathExtension().lastPathComponent
        let directory = input.deletingLastPathComponent()
        let folder = Self.uniqueFolder(directory.appendingPathComponent("\(base) Split"))

        do {
            try FileManager.default.createDirectory(
                at: folder, withIntermediateDirectories: true
            )
            var outputs: [URL] = []

            for (index, pages) in ranges.enumerated() {
                if Task.isCancelled { throw CancellationError() }
                let part = PDFDocument()
                for pageNumber in pages {
                    guard let page = document.page(at: pageNumber - 1) else { continue }
                    part.insert(page, at: part.pageCount)
                }
                let url = folder.appendingPathComponent("part \(index + 1).pdf")
                guard part.write(to: url) else {
                    throw EngineError.writeFailed("could not write part \(index + 1)")
                }
                outputs.append(url)
                progress(Double(index + 1) / Double(ranges.count))
            }

            return outputs
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }

    // MARK: Ranges

    /// 1-based page numbers for each output part.
    static func ranges(_ spec: PDFSplitSpec, pageCount: Int) -> [[Int]] {
        guard pageCount > 0 else { return [] }

        switch spec.mode {
        case .atPages:
            let starts = ([1] + spec.pages.filter { $0 > 1 && $0 <= pageCount }).sorted()
            var result: [[Int]] = []
            for (index, start) in starts.enumerated() {
                let end = index + 1 < starts.count ? starts[index + 1] - 1 : pageCount
                if start <= end {
                    result.append(Array(start...end))
                }
            }
            return result

        case .equalParts:
            let parts = max(2, min(spec.parts, pageCount))
            let size = Int(ceil(Double(pageCount) / Double(parts)))
            var result: [[Int]] = []
            var start = 1
            while start <= pageCount {
                let end = min(pageCount, start + size - 1)
                result.append(Array(start...end))
                start = end + 1
            }
            return result
        }
    }

    private static func uniqueFolder(_ url: URL) -> URL {
        var candidate = url
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = url.deletingLastPathComponent()
                .appendingPathComponent("\(url.lastPathComponent) \(index)")
            index += 1
        }
        return candidate
    }
}
