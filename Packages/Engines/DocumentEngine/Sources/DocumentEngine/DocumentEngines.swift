import AppKit
import Foundation
import ImageIO
import PDFKit
import JobCore
import EngineKit
import PDFEngine

// MARK: - Documents → PDF, images and text formats

public struct DocumentConversionEngine: Engine {
    public let id = "document.convert"

    private static let sources: Set<String> = [
        "txt", "md", "markdown", "html", "htm", "rtf", "rtfd",
        "docx", "odt", "epub", "webarchive"
    ]
    private static let targets: Set<String> = [
        "pdf", "jpg", "jpeg", "png", "txt", "md", "html", "rtf",
        "rtfd", "docx", "epub"
    ]

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
            throw EngineError.corruptInput("(missing document)")
        }
        let target = targetRaw.lowercased()
        let title = input.deletingPathExtension().lastPathComponent

        let boxed = try await MainActor.run {
            BoxedAttributedString(try DocumentIO.load(input))
        }
        let attributed = boxed.value
        let body = DocumentIO.plainText(attributed)
        guard !body.isEmpty || attributed.length > 0 else {
            throw DocumentError.emptyDocument
        }
        let pages = [body.isEmpty ? attributed.string : body]

        switch target {
        case "pdf":
            let output = DestinationPolicy.outputURL(for: input, extension: "pdf")
            try await MainActor.run {
                try TextPDFRenderer.render(boxed.value, title: title, to: output)
            }
            progress(1)
            return [output]

        case "jpg", "jpeg", "png":
            return try await renderImages(
                boxed: boxed,
                title: title,
                input: input,
                target: target,
                progress: progress
            )

        case "txt":
            let output = DestinationPolicy.outputURL(for: input, extension: "txt")
            try DocumentWriters.writeText(pages, to: output)
            progress(1)
            return [output]

        case "md":
            let output = DestinationPolicy.outputURL(for: input, extension: "md")
            try DocumentWriters.writeMarkdown(pages, title: title, to: output)
            progress(1)
            return [output]

        case "html":
            let output = DestinationPolicy.outputURL(for: input, extension: "html")
            try DocumentWriters.writeHTML(pages, title: title, to: output)
            progress(1)
            return [output]

        case "rtf":
            let output = DestinationPolicy.outputURL(for: input, extension: "rtf")
            try DocumentWriters.writeRTF(pages, title: title, to: output)
            progress(1)
            return [output]

        case "rtfd":
            let output = DestinationPolicy.outputURL(for: input, extension: "rtfd")
            try DocumentWriters.writeRTFD(pages, title: title, to: output)
            progress(1)
            return [output]

        case "docx":
            let output = DestinationPolicy.outputURL(for: input, extension: "docx")
            try DocumentWriters.writeDOCX(pages, title: title, to: output)
            progress(1)
            return [output]

        case "epub":
            let output = DestinationPolicy.outputURL(for: input, extension: "epub")
            try DocumentWriters.writeEPUB(pages, title: title, to: output)
            progress(1)
            return [output]

        default:
            throw EngineError.unsupported("document → \(target)")
        }
    }

    private func renderImages(
        boxed: BoxedAttributedString,
        title: String,
        input: URL,
        target: String,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> [URL] {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let temporaryPDF = directory.appendingPathComponent("\(title).pdf")
        try await MainActor.run {
            try TextPDFRenderer.render(boxed.value, title: title, to: temporaryPDF)
        }

        let ext = target == "jpeg" ? "jpg" : target
        let job = Job(inputs: [temporaryPDF], operation: .convert(to: ext))
        let engine = PDFToImageEngine(dpi: 200)
        let rendered = try await engine.run(job) { value in
            progress(value * 0.9)
        }

        let destinationDirectory = input.deletingLastPathComponent()
        var outputs: [URL] = []
        for source in rendered {
            let candidate = destinationDirectory
                .appendingPathComponent(source.lastPathComponent)
            let destination = DestinationPolicy.unique(candidate)
            try FileManager.default.moveItem(at: source, to: destination)
            outputs.append(destination)
        }
        progress(1)
        return outputs
    }
}

// MARK: - PDFs → HTML, RTF, RTFD, EPUB, DOCX and SVG

public struct PDFDocumentEngine: Engine {
    public let id = "pdf.document"
    private let svgDPI: CGFloat

    public init(svgDPI: CGFloat = 200) {
        self.svgDPI = svgDPI
    }

    public func canHandle(_ job: Job) -> Bool {
        guard case .convert(let target) = job.operation,
              let input = job.inputs.first,
              input.pathExtension.lowercased() == "pdf" else { return false }
        return ["html", "rtf", "rtfd", "epub", "docx", "svg"]
            .contains(target.lowercased())
    }

    public func run(
        _ job: Job,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> [URL] {
        guard let input = job.inputs.first,
              case .convert(let targetRaw) = job.operation else {
            throw EngineError.corruptInput("(missing PDF)")
        }
        let target = targetRaw.lowercased()
        guard let document = PDFDocument(url: input), document.pageCount > 0 else {
            throw EngineError.corruptInput(input.lastPathComponent)
        }
        let title = input.deletingPathExtension().lastPathComponent

        if target == "svg" {
            return try renderSVG(document: document, input: input, title: title, progress: progress)
        }

        var pages: [String] = []
        for index in 0..<document.pageCount {
            if Task.isCancelled { throw CancellationError() }
            pages.append(
                PDFTextExtractor.text(document.page(at: index))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            )
            progress(Double(index + 1) / Double(document.pageCount) * 0.8)
        }
        let usable = pages.filter { !$0.isEmpty }
        guard !usable.isEmpty else {
            throw DocumentError.emptyDocument
        }
        let content = usable

        switch target {
        case "html":
            let output = DestinationPolicy.outputURL(for: input, extension: "html")
            try DocumentWriters.writeHTML(content, title: title, to: output)
            return [output]
        case "rtf":
            let output = DestinationPolicy.outputURL(for: input, extension: "rtf")
            try DocumentWriters.writeRTF(content, title: title, to: output)
            return [output]
        case "rtfd":
            let output = DestinationPolicy.outputURL(for: input, extension: "rtfd")
            try DocumentWriters.writeRTFD(content, title: title, to: output)
            return [output]
        case "epub":
            let output = DestinationPolicy.outputURL(for: input, extension: "epub")
            try DocumentWriters.writeEPUB(content, title: title, to: output)
            return [output]
        case "docx":
            let output = DestinationPolicy.outputURL(for: input, extension: "docx")
            try DocumentWriters.writeDOCX(content, title: title, to: output)
            return [output]
        default:
            throw EngineError.unsupported("PDF → \(target)")
        }
    }

    private func renderSVG(
        document: PDFDocument,
        input: URL,
        title: String,
        progress: @Sendable @escaping (Double) -> Void
    ) throws -> [URL] {
        var outputs: [URL] = []
        let directory = input.deletingLastPathComponent()

        for index in 0..<document.pageCount {
            if Task.isCancelled { throw CancellationError() }
            guard let page = document.page(at: index),
                  let image = PDFTextExtractor.rasterise(page, dpi: svgDPI),
                  let png = pngData(image) else {
                throw EngineError.writeFailed("page \(index + 1) produced no image")
            }
            let bounds = page.bounds(for: .mediaBox)
            let base64 = png.base64EncodedString()

            let candidate: URL
            if document.pageCount == 1 {
                candidate = directory.appendingPathComponent("\(title).svg")
            } else {
                candidate = directory.appendingPathComponent("\(title) \(index + 1).svg")
            }
            let output = DestinationPolicy.unique(candidate)

            let svg = """
            <?xml version="1.0" encoding="UTF-8"?>
            <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
                 width="\(format(bounds.width))" height="\(format(bounds.height))"
                 viewBox="0 0 \(format(bounds.width)) \(format(bounds.height))">
            <title>\(DocumentWriters.xmlEscape(title)) — \(index + 1)</title>
            <image width="\(format(bounds.width))" height="\(format(bounds.height))"
                   xlink:href="data:image/png;base64,\(base64)"/>
            </svg>
            """
            try writeAtomically(to: output) { temporary in
                try svg.data(using: .utf8)?.write(to: temporary, options: .atomic)
            }
            outputs.append(output)
            progress(Double(index + 1) / Double(document.pageCount))
        }
        return outputs
    }

    private func pngData(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            "public.png" as CFString,
            1,
            nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private func format(_ value: CGFloat) -> String {
        String(format: "%.2f", value)
    }
}
