import Foundation
import PDFKit
import JobCore
import EngineKit

public struct PDFMergeEngine: Engine {
    public let id = "pdf.merge"

    public init() {}

    public func canHandle(_ job: Job) -> Bool {
        if case .pdfMerge = job.operation { return true }
        return false
    }

    public func run(
        _ job: Job,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> [URL] {
        guard case .pdfMerge = job.operation else {
            throw EngineError.unsupported("\(job.operation)")
        }
        guard job.inputs.count >= 2 else {
            throw EngineError.unsupported("Select at least two PDFs to merge")
        }

        let merged = PDFDocument()
        for input in job.inputs {
            guard let document = PDFDocument(url: input) else {
                throw EngineError.corruptInput(input.lastPathComponent)
            }
            for index in 0..<document.pageCount {
                if Task.isCancelled { throw CancellationError() }
                guard let page = document.page(at: index) else { continue }
                merged.insert(page, at: merged.pageCount)
            }
        }

        guard merged.pageCount > 0 else {
            throw EngineError.corruptInput(job.inputs[0].lastPathComponent)
        }

        let first = job.inputs[0]
        let base = first.deletingPathExtension().lastPathComponent
        let directory = first.deletingLastPathComponent()
        let candidate = directory.appendingPathComponent("\(base) Merged.pdf")
        let output = DestinationPolicy.unique(candidate)

        try writeAtomically(to: output) { tmp in
            guard merged.write(to: tmp) else {
                throw EngineError.writeFailed("PDFKit could not write the merged file")
            }
        }

        progress(1)
        return [output]
    }
}
