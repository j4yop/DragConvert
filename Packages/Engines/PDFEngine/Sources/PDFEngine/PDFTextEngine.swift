import AppKit
import CoreGraphics
import Foundation
import PDFKit
import Vision
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
            pages.append(pageText(document.page(at: index)))
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

    private func pageText(_ page: PDFPage?) -> String {
        guard let page else { return "" }

        if let selectable = page.string?.trimmingCharacters(in: .whitespacesAndNewlines),
           !selectable.isEmpty {
            return selectable
        }

        guard let image = rasterise(page) else {
            return page.string ?? ""
        }
        return recognise(image) ?? (page.string ?? "")
    }

    private func rasterise(_ page: PDFPage) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        let scale = ocrDPI / 72
        let width = max(1, Int((bounds.width * scale).rounded()))
        let height = max(1, Int((bounds.height * scale).rounded()))

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }

        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.saveGState()
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
        context.restoreGState()
        return context.makeImage()
    }

    private func recognise(_ image: CGImage) -> String? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            Log.engine("pdf ocr failed: \(error.localizedDescription)")
            return nil
        }

        let observations = (request.results ?? []).sorted { left, right in
            if abs(left.boundingBox.maxY - right.boundingBox.maxY) > 0.01 {
                return left.boundingBox.maxY > right.boundingBox.maxY
            }
            return left.boundingBox.minX < right.boundingBox.minX
        }

        let lines = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }
        let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}

private enum Log {
    static func engine(_ message: String) {
        NSLog("[dragconvert] \(message)")
    }
}
