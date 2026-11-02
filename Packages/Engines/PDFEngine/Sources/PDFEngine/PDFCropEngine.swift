import Foundation
import PDFKit
import JobCore
import EngineKit

public struct PDFCropEngine: Engine {
    public let id = "pdf.crop"

    public init() {}

    public func canHandle(_ job: Job) -> Bool {
        if case .pdfCrop = job.operation { return true }
        return false
    }

    public func run(
        _ job: Job,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> [URL] {
        guard let input = job.inputs.first else {
            throw EngineError.corruptInput("(missing file)")
        }
        guard case .pdfCrop(let spec) = job.operation else {
            throw EngineError.unsupported("\(job.operation)")
        }
        guard let source = PDFDocument(url: input), source.pageCount > 0 else {
            throw EngineError.corruptInput(input.lastPathComponent)
        }

        let nx = min(max(spec.x, 0), 1)
        let ny = min(max(spec.y, 0), 1)
        let nw = min(max(spec.width, 0.01), 1 - nx)
        let nh = min(max(spec.height, 0.01), 1 - ny)

        let output = PDFDocument()
        for index in 0..<source.pageCount {
            if Task.isCancelled { throw CancellationError() }
            guard let original = source.page(at: index),
                  let page = original.copy() as? PDFPage else { continue }

            let media = page.bounds(for: .mediaBox)
            let crop = CGRect(
                x: media.minX + nx * media.width,
                y: media.maxY - (ny + nh) * media.height,
                width: nw * media.width,
                height: nh * media.height
            )
            page.setBounds(crop, for: .mediaBox)
            page.setBounds(crop, for: .cropBox)
            output.insert(page, at: output.pageCount)
        }

        guard output.pageCount > 0 else {
            throw EngineError.writeFailed("the cropped PDF has no pages")
        }

        let base = input.deletingPathExtension().lastPathComponent
        let directory = input.deletingLastPathComponent()
        let candidate = directory.appendingPathComponent("\(base) Cropped.pdf")
        let destination = DestinationPolicy.unique(candidate)

        try writeAtomically(to: destination) { tmp in
            guard output.write(to: tmp) else {
                throw EngineError.writeFailed("PDFKit could not write the cropped file")
            }
        }

        progress(1)
        return [destination]
    }
}
