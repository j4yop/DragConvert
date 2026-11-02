import Foundation
import AppKit
import PDFKit
import JobCore
import EngineKit

public struct PDFAnnotateEngine: Engine {
    public let id = "pdf.annotate"

    public init() {}

    public func canHandle(_ job: Job) -> Bool {
        if case .pdfAnnotate = job.operation { return true }
        return false
    }

    public func run(
        _ job: Job,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> [URL] {
        guard let input = job.inputs.first else {
            throw EngineError.corruptInput("(missing file)")
        }
        guard case .pdfAnnotate(let spec) = job.operation else {
            throw EngineError.unsupported("\(job.operation)")
        }
        guard !spec.annotations.isEmpty else {
            throw EngineError.unsupported("Add at least one annotation")
        }
        guard let document = PDFDocument(url: input), document.pageCount > 0 else {
            throw EngineError.corruptInput(input.lastPathComponent)
        }

        for item in spec.annotations {
            guard let page = document.page(at: item.pageIndex) else { continue }
            let box = page.bounds(for: .mediaBox)
            let color = NSColor(
                srgbRed: item.color.red,
                green: item.color.green,
                blue: item.color.blue,
                alpha: item.color.alpha
            )
            let border = PDFBorder()
            border.lineWidth = item.lineWidth
            border.style = .solid

            switch item.kind {
            case .rectangle, .ellipse:
                let annotation = PDFAnnotation(
                    bounds: pageRect(item.rect, in: box),
                    forType: item.kind == .rectangle ? .square : .circle,
                    withProperties: nil
                )
                annotation.color = color.withAlphaComponent(0.15)
                annotation.border = border
                page.addAnnotation(annotation)

            case .arrow:
                let points = item.points.map { pagePoint($0, in: box) }
                guard points.count >= 2 else { continue }
                let start = points[0]
                let end = points[1]
                let bounds = CGRect(
                    x: min(start.x, end.x),
                    y: min(start.y, end.y),
                    width: abs(end.x - start.x),
                    height: abs(end.y - start.y)
                ).insetBy(dx: -6, dy: -6)
                let annotation = PDFAnnotation(
                    bounds: bounds, forType: .line, withProperties: nil
                )
                annotation.startPoint = start
                annotation.endPoint = end
                annotation.endLineStyle = .closedArrow
                annotation.color = color
                annotation.border = border
                page.addAnnotation(annotation)

            case .ink:
                let points = item.points.map { pagePoint($0, in: box) }
                guard points.count > 1 else { continue }
                let path = NSBezierPath()
                path.move(to: points[0])
                for point in points.dropFirst() { path.line(to: point) }
                let annotation = PDFAnnotation(
                    bounds: path.bounds.insetBy(dx: -2, dy: -2),
                    forType: .ink,
                    withProperties: nil
                )
                annotation.add(path)
                annotation.color = color
                annotation.border = border
                page.addAnnotation(annotation)

            case .text:
                let annotation = PDFAnnotation(
                    bounds: pageRect(item.rect, in: box),
                    forType: .freeText,
                    withProperties: nil
                )
                annotation.contents = item.text ?? "Note"
                annotation.font = NSFont.systemFont(ofSize: 14, weight: .medium)
                annotation.fontColor = color
                annotation.color = .clear
                page.addAnnotation(annotation)
            }
        }

        let base = input.deletingPathExtension().lastPathComponent
        let directory = input.deletingLastPathComponent()
        let candidate = directory.appendingPathComponent("\(base) Annotated.pdf")
        let output = DestinationPolicy.unique(candidate)

        try writeAtomically(to: output) { tmp in
            guard document.write(to: tmp) else {
                throw EngineError.writeFailed("PDFKit could not write the annotated file")
            }
        }

        progress(1)
        return [output]
    }

    private func pageRect(_ rect: PDFRect, in box: CGRect) -> CGRect {
        CGRect(
            x: box.minX + rect.x * box.width,
            y: box.maxY - (rect.y + rect.height) * box.height,
            width: rect.width * box.width,
            height: rect.height * box.height
        )
    }

    private func pagePoint(_ point: PDFPoint, in box: CGRect) -> CGPoint {
        CGPoint(
            x: box.minX + point.x * box.width,
            y: box.maxY - point.y * box.height
        )
    }
}
