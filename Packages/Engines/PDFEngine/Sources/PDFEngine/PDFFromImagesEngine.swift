import Foundation
import CoreGraphics
import JobCore
import EngineKit
import ImageEngine

public struct PDFFromImagesEngine: Engine {
    public let id = "pdf.from-images"

    public init() {}

    public func canHandle(_ job: Job) -> Bool {
        if case .pdfFromImages = job.operation { return true }
        return false
    }

    public func run(
        _ job: Job,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> [URL] {
        guard case .pdfFromImages = job.operation else {
            throw EngineError.unsupported("\(job.operation)")
        }
        guard !job.inputs.isEmpty else {
            throw EngineError.corruptInput("(no images)")
        }

        let images = job.inputs.compactMap { input -> (URL, CGImage)? in
            guard let image = ImageConvertEngine.loadImage(at: input) else { return nil }
            return (input, image)
        }
        guard images.count == job.inputs.count else {
            throw EngineError.corruptInput("one of the images could not be read")
        }

        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else {
            throw EngineError.writeFailed("could not create a PDF consumer")
        }
        var defaultBox = CGRect(
            x: 0, y: 0,
            width: CGFloat(images[0].1.width),
            height: CGFloat(images[0].1.height)
        )
        guard let context = CGContext(
            consumer: consumer, mediaBox: &defaultBox, nil
        ) else {
            throw EngineError.writeFailed("could not create a PDF context")
        }

        for (_, image) in images {
            if Task.isCancelled { throw CancellationError() }
            let box = CGRect(
                x: 0, y: 0,
                width: CGFloat(image.width),
                height: CGFloat(image.height)
            )
            let boxData = withUnsafeBytes(of: box) { Data($0) as CFData }
            let info = [kCGPDFContextMediaBox: boxData] as CFDictionary
            context.beginPDFPage(info)
            context.draw(image, in: box)
            context.endPDFPage()
        }
        context.closePDF()

        let first = job.inputs[0]
        let base = first.deletingPathExtension().lastPathComponent
        let directory = first.deletingLastPathComponent()
        let candidate = directory.appendingPathComponent("\(base) Images.pdf")
        let output = DestinationPolicy.unique(candidate)

        try writeAtomically(to: output) { tmp in
            try (data as Data).write(to: tmp, options: .atomic)
        }

        progress(1)
        return [output]
    }
}
