import AppKit
import Foundation
import PDFKit
import JobCore
import EngineKit

/// Extracts selectable text, falling back to on-device Vision OCR for
/// scanned pages. No network, no external service.
public struct PDFTextEngine: Engine {
    public let id = "pdf.text"
    private let ocrDPI: CGFloat

    public init(ocrDPI: CGFloat = 150) {
        self.ocrDPI = ocrDPI
    }

    public func canHandle(_ job: Job) -> Bool {
        guard case .convert(let ext) = job.operation else { return false }
        return ext.lowercased() == "txt" || ext.lowercased() == "md"
    }

    public func run(
        _ job: Job,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> [URL] {
        guard let input = job.inputs.first else {
            throw EngineError.corruptInput("(missing file)")
        }
        guard let document = PDFDocument(url: input), document.pageCount > 0 else {
            throw EngineError.corruptInput(input.lastPathComponent)
        }
        guard case .convert(let ext) = job.operation else {
            throw EngineError.unsupported("\(job.operation)")
        }

        var pages: [String] = []
        for index in 0..<document.pageCount {
            if Task.isCancelled { throw CancellationError() }
            pages.append(PDFTextExtractor.text(document.page(at: index), ocrDPI: ocrDPI))
            progress(Double(index + 1) / Double(document.pageCount))
        }

        let body = pages
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        let content: String
        if ext.lowercased() == "md" {
            let title = input.deletingPathExtension().lastPathComponent
            content = "# \(title)\n\n\(body)\n"
        } else {
            content = body + "\n"
        }

        let output = DestinationPolicy.outputURL(for: input, extension: ext.lowercased())
        try writeAtomically(to: output) { tmp in
            guard let data = content.data(using: .utf8) else {
                throw EngineError.writeFailed("could not encode text")
            }
            try data.write(to: tmp, options: .atomic)
        }
        return [output]
    }
}
