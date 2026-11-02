import Foundation
import AppKit
import PDFKit
import ImageIO
import UniformTypeIdentifiers
import JobCore
import EngineKit

public struct PDFToImageEngine: Engine {
    public let id = "pdf.to-image"
    private let dpi: CGFloat

    public init(dpi: CGFloat = 300) {
        self.dpi = dpi
    }

    public func canHandle(_ job: Job) -> Bool {
        guard case .convert(let ext) = job.operation else { return false }
        return Self.uti(forExtension: ext) != nil
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
        guard case .convert(let ext) = job.operation,
              let uti = Self.uti(forExtension: ext) else {
            throw EngineError.unsupported("PDF → \(job.operation)")
        }

        let scale = dpi / 72
        let base = input.deletingPathExtension().lastPathComponent
        let directory = input.deletingLastPathComponent()
        var outputs: [URL] = []

        for index in 0..<document.pageCount {
            if Task.isCancelled { throw CancellationError() }
            guard let page = document.page(at: index) else { continue }

            let bounds = page.bounds(for: .mediaBox)
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
            ) else {
                throw EngineError.writeFailed("could not create a bitmap context")
            }

            context.setFillColor(NSColor.white.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.saveGState()
            context.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: context)
            context.restoreGState()

            guard let image = context.makeImage() else {
                throw EngineError.writeFailed("page \(index + 1) produced no image")
            }

            let candidate: URL
            if document.pageCount == 1 {
                candidate = directory.appendingPathComponent("\(base).\(ext)")
            } else {
                candidate = directory.appendingPathComponent("\(base) \(index + 1).\(ext)")
            }
            let output = DestinationPolicy.unique(candidate)

            try writeAtomically(to: output) { tmp in
                guard let destination = CGImageDestinationCreateWithURL(
                    tmp as CFURL, uti.identifier as CFString, 1, nil
                ) else {
                    throw EngineError.writeFailed("could not open \(tmp.lastPathComponent)")
                }
                let properties: CFDictionary?
                if uti == .jpeg {
                    properties = [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary
                } else {
                    properties = nil
                }
                CGImageDestinationAddImage(destination, image, properties)
                guard CGImageDestinationFinalize(destination) else {
                    throw EngineError.writeFailed("encoder rejected the page")
                }
            }

            outputs.append(output)
            progress(Double(index + 1) / Double(document.pageCount))
        }

        return outputs
    }

    static func uti(forExtension ext: String) -> UTType? {
        switch ext.lowercased() {
        case "jpg", "jpeg": return .jpeg
        case "png": return .png
        case "tif", "tiff": return .tiff
        default: return nil
        }
    }
}
