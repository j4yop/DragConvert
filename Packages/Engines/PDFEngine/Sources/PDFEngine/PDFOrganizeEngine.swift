import Foundation
import PDFKit
import JobCore
import EngineKit

public struct PDFOrganizeEngine: Engine {
    public let id = "pdf.organize"

    public init() {}

    public func canHandle(_ job: Job) -> Bool {
        if case .pdfOrganize = job.operation { return true }
        return false
    }

    public func run(
        _ job: Job,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> [URL] {
        guard let input = job.inputs.first else {
            throw EngineError.corruptInput("(missing file)")
        }
        guard case .pdfOrganize(let spec) = job.operation else {
            throw EngineError.unsupported("\(job.operation)")
        }
        guard !spec.pages.isEmpty else {
            throw EngineError.unsupported("Keep at least one page")
        }
        guard let source = PDFDocument(url: input), source.pageCount > 0 else {
            throw EngineError.corruptInput(input.lastPathComponent)
        }

        let output = PDFDocument()
        for entry in spec.pages {
            if Task.isCancelled { throw CancellationError() }
            guard let original = source.page(at: entry.sourceIndex),
                  let page = original.copy() as? PDFPage else {
                continue
            }
            let turns = ((entry.rotation % 4) + 4) % 4
            page.rotation = ((page.rotation + turns * 90) % 360 + 360) % 360
            output.insert(page, at: output.pageCount)
        }

        guard output.pageCount > 0 else {
            throw EngineError.writeFailed("the organized PDF has no pages")
        }

        let base = input.deletingPathExtension().lastPathComponent
        let directory = input.deletingLastPathComponent()
        let candidate = directory.appendingPathComponent("\(base) Organized.pdf")
        let destination = DestinationPolicy.unique(candidate)

        try writeAtomically(to: destination) { tmp in
            guard output.write(to: tmp) else {
                throw EngineError.writeFailed("PDFKit could not write the organized file")
            }
        }

        progress(1)
        return [destination]
    }
}
