import Foundation
import PDFKit
import CoreGraphics
import ImageIO

enum PDFAError: LocalizedError {
    case unreadable
    case noPages
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .unreadable: return "This PDF could not be opened."
        case .noPages: return "This PDF has no pages."
        case .writeFailed(let detail): return detail
        }
    }
}

/// Writes a conservative PDF/A-2b-style archive: an sRGB output intent, XMP
/// identification and a fresh PDF with every page redrawn. It is deliberately
/// fail-closed: if the source or the output cannot be verified, nothing is saved.
enum PDFAConverter {
    static func convert(_ input: URL) throws -> URL {
        guard let document = PDFDocument(url: input), document.pageCount > 0 else {
            throw PDFAError.unreadable
        }
        let output = outputURL(for: input)
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        let info: [CFString: Any] = [
            kCGPDFContextCreator: "DragConvert" as CFString,
            kCGPDFContextTitle: input.deletingPathExtension().lastPathComponent as CFString,
            kCGPDFContextCreatePDFA: true
        ]
        guard let context = CGContext(
            output as CFURL,
            mediaBox: &mediaBox,
            info as CFDictionary
        ) else {
            throw PDFAError.writeFailed("Could not create the PDF/A file.")
        }

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            var pageBox = page.bounds(for: .mediaBox)
            if pageBox.width < 3 || pageBox.height < 3 {
                pageBox = mediaBox
            }
            let pageInfo: [CFString: Any] = [
                kCGPDFContextMediaBox: NSData(
                    bytes: &pageBox,
                    length: MemoryLayout<CGRect>.size
                )
            ]
            context.beginPDFPage(pageInfo as CFDictionary)
            page.draw(with: .mediaBox, to: context)
            context.endPDFPage()
        }
        context.closePDF()

        guard let check = PDFDocument(url: output), check.pageCount == document.pageCount else {
            try? FileManager.default.removeItem(at: output)
            throw PDFAError.writeFailed("The PDF/A file could not be verified.")
        }
        return output
    }

    private static func outputURL(for input: URL) -> URL {
        let directory = input.deletingLastPathComponent()
        let base = input.deletingPathExtension().lastPathComponent + " PDFA"
        var candidate = directory.appendingPathComponent(base).appendingPathExtension("pdf")
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory
                .appendingPathComponent("\(base) \(index)")
                .appendingPathExtension("pdf")
            index += 1
        }
        return candidate
    }
}
