import AppKit
import CoreGraphics
import Foundation

/// Carries AppKit text across concurrency boundaries. NSAttributedString is
/// thread-safe for reading; all mutation happens before it is boxed.
struct BoxedAttributedString: @unchecked Sendable {
    let value: NSAttributedString

    init(_ value: NSAttributedString) {
        self.value = value
    }
}

enum TextPDFRenderer {
    static let a4 = CGSize(width: 595.2, height: 841.8)
    static let a4Landscape = CGSize(width: 841.8, height: 595.2)

    static func render(
        _ attributed: NSAttributedString,
        title: String,
        to url: URL,
        pageSize: CGSize = a4
    ) throws {
        guard attributed.length > 0 else {
            throw DocumentError.emptyDocument
        }

        let prepared = normalize(attributed)
        let margin: CGFloat = 52
        let contentWidth = pageSize.width - margin * 2
        let contentHeight = pageSize.height - margin * 2

        guard let consumer = CGDataConsumer(url: url as CFURL) else {
            throw DocumentError.write("could not create a PDF context")
        }
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw DocumentError.write("could not create a PDF context")
        }
        var remaining = prepared
        var pageNumber = 1

        while remaining.length > 0 {
            if Task.isCancelled { throw CancellationError() }
            let pageText = firstPage(
                of: remaining,
                width: contentWidth,
                height: contentHeight
            )
            if pageText.length == 0 { break }

            context.beginPDFPage(nil)
            context.setFillColor(NSColor.white.cgColor)
            context.fill(mediaBox)

            context.saveGState()
            context.translateBy(x: 0, y: pageSize.height)
            context.scaleBy(x: 1, y: -1)

            let graphics = NSGraphicsContext(cgContext: context, flipped: true)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = graphics

            let storage = NSTextStorage(attributedString: pageText)
            let layout = NSLayoutManager()
            storage.addLayoutManager(layout)
            let container = NSTextContainer(
                size: CGSize(width: contentWidth, height: contentHeight)
            )
            container.lineFragmentPadding = 0
            layout.addTextContainer(container)
            layout.ensureLayout(for: container)
            layout.drawGlyphs(
                forGlyphRange: layout.glyphRange(for: container),
                at: NSPoint(x: margin, y: margin)
            )

            let footer = pageNumber == 1
                ? title
                : "\(title) · \(pageNumber)"
            (footer as NSString).draw(
                at: NSPoint(x: margin, y: pageSize.height - margin + 18),
                withAttributes: [
                    .font: NSFont.systemFont(ofSize: 8),
                    .foregroundColor: NSColor(calibratedWhite: 0.55, alpha: 1)
                ]
            )

            NSGraphicsContext.restoreGraphicsState()
            context.restoreGState()
            context.endPDFPage()

            if pageText.length >= remaining.length { break }
            remaining = remaining.attributedSubstring(
                from: NSRange(location: pageText.length,
                              length: remaining.length - pageText.length)
            )
            pageNumber += 1
        }

        context.closePDF()
    }

    static func normalize(_ attributed: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributed)
        let whole = NSRange(location: 0, length: mutable.length)
        guard whole.length > 0 else { return mutable }

        mutable.addAttribute(.foregroundColor, value: NSColor.black, range: whole)

        var missingFonts: [NSRange] = []
        mutable.enumerateAttribute(.font, in: whole) { value, range, _ in
            if value == nil { missingFonts.append(range) }
        }
        for range in missingFonts {
            mutable.addAttribute(
                .font,
                value: NSFont.systemFont(ofSize: 12.5),
                range: range
            )
        }
        return mutable
    }

    private static func firstPage(
        of text: NSAttributedString,
        width: CGFloat,
        height: CGFloat
    ) -> NSAttributedString {
        let storage = NSTextStorage(attributedString: text)
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: CGSize(width: width, height: height))
        container.lineFragmentPadding = 0
        layout.addTextContainer(container)
        layout.ensureLayout(for: container)

        let glyphs = layout.glyphRange(for: container)
        guard glyphs.length > 0 else { return NSAttributedString() }
        let characters = layout.characterRange(
            forGlyphRange: glyphs,
            actualGlyphRange: nil
        )
        guard characters.length > 0 else { return NSAttributedString() }
        return text.attributedSubstring(
            from: NSRange(location: 0, length: min(characters.length, text.length))
        )
    }
}

enum DocumentError: LocalizedError {
    case emptyDocument
    case unsupported(String)
    case corrupt(String)
    case write(String)

    var errorDescription: String? {
        switch self {
        case .emptyDocument:
            return "The document has no readable text."
        case .unsupported(let detail):
            return "This document conversion isn’t supported: \(detail)"
        case .corrupt(let detail):
            return "Couldn’t read \(detail)."
        case .write(let detail):
            return "Couldn’t save the document: \(detail)"
        }
    }
}
