import AppKit
import Foundation
import JobCore
import EngineKit

public struct SpreadsheetEngine: Engine {
    public let id = "spreadsheet.convert"

    private static let sources: Set<String> = ["csv", "tsv", "xlsx", "ods"]
    private static let targets: Set<String> = ["xlsx", "ods", "csv", "tsv", "pdf"]

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
            throw EngineError.corruptInput("(missing spreadsheet)")
        }
        let target = targetRaw.lowercased()
        let rows = try readRows(input)
        guard !rows.isEmpty else {
            throw DocumentError.emptyDocument
        }
        let title = input.deletingPathExtension().lastPathComponent

        switch target {
        case "xlsx":
            let output = DestinationPolicy.outputURL(for: input, extension: "xlsx")
            try SpreadsheetFile.writeXLSX(rows, to: output)
            progress(1)
            return [output]

        case "ods":
            let output = DestinationPolicy.outputURL(for: input, extension: "ods")
            try SpreadsheetFile.writeODS(rows, to: output)
            progress(1)
            return [output]

        case "csv", "tsv":
            let separator: Character = target == "tsv" ? "\t" : ","
            let output = DestinationPolicy.outputURL(for: input, extension: target)
            try writeAtomically(to: output) { temporary in
                let text = DelimitedText.encode(rows, separator: separator)
                try text.data(using: .utf8)?.write(to: temporary, options: .atomic)
            }
            progress(1)
            return [output]

        case "pdf":
            let output = DestinationPolicy.outputURL(for: input, extension: "pdf")
            let boxed = try await MainActor.run {
                BoxedAttributedString(
                    try DocumentIO.html(
                        Self.tableHTML(rows: rows, title: title),
                        baseURL: nil,
                        name: input.lastPathComponent
                    )
                )
            }
            try await MainActor.run {
                try TextPDFRenderer.render(
                    boxed.value,
                    title: title,
                    to: output,
                    pageSize: TextPDFRenderer.a4Landscape
                )
            }
            progress(1)
            return [output]

        default:
            throw EngineError.unsupported("spreadsheet → \(target)")
        }
    }

    private func readRows(_ input: URL) throws -> [[String]] {
        switch input.pathExtension.lowercased() {
        case "csv", "tsv":
            return try DelimitedText.read(input)
        case "xlsx":
            return try SpreadsheetFile.readXLSX(input)
        case "ods":
            return try SpreadsheetFile.readODS(input)
        default:
            throw EngineError.unsupported(input.pathExtension)
        }
    }

    private static func tableHTML(rows: [[String]], title: String) -> Data {
        let body = rows.enumerated().map { index, row in
            let tag = index == 0 ? "th" : "td"
            let cells = row.map { value in
                let content = value.isEmpty ? "&#160;" : DocumentWriters.xmlEscape(value)
                return "<\(tag)>\(content)</\(tag)>"
            }.joined()
            return "<tr>\(cells)</tr>"
        }.joined(separator: "\n")

        let html = """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8">
        <style>
        body { font: 9.5px -apple-system, Helvetica, sans-serif; color: #111; }
        h1 { font-size: 15px; margin: 0 0 10px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #aaa; padding: 3px 5px; text-align: left; vertical-align: top; }
        th { background: #eee; font-weight: 600; }
        </style></head>
        <body><h1>\(DocumentWriters.xmlEscape(title))</h1>
        <table>\(body)</table></body></html>
        """
        return Data(html.utf8)
    }
}
