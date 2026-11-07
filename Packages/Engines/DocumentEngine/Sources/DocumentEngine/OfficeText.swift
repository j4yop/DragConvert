import AppKit
import Foundation

/// Reads the text layer of DOCX and ODT packages directly. This avoids
/// `textutil`, whose HTML/RTF import can stall inside the App Sandbox.
enum OfficeText {
    fileprivate struct Paragraph {
        let text: String
        let style: String
        let bold: Bool
        let italic: Bool
        var bullet: Bool = false
    }

    static func loadDOCX(_ url: URL) throws -> NSAttributedString {
        guard let archive = ZipReader(url: url),
              let data = archive.read("word/document.xml") else {
            throw DocumentError.corrupt(url.lastPathComponent)
        }
        let parser = DOCXParser()
        let xml = XMLParser(data: data)
        xml.delegate = parser
        guard xml.parse() else {
            throw DocumentError.corrupt(url.lastPathComponent)
        }
        return render(parser.paragraphs)
    }

    static func loadODT(_ url: URL) throws -> NSAttributedString {
        guard let archive = ZipReader(url: url),
              let data = archive.read("content.xml") else {
            throw DocumentError.corrupt(url.lastPathComponent)
        }
        let parser = ODTParser()
        let xml = XMLParser(data: data)
        xml.delegate = parser
        guard xml.parse() else {
            throw DocumentError.corrupt(url.lastPathComponent)
        }
        return render(parser.paragraphs)
    }

    private static func render(_ paragraphs: [Paragraph]) -> NSAttributedString {
        let output = NSMutableAttributedString()
        let usable = paragraphs.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !usable.isEmpty else {
            return NSAttributedString()
        }

        for paragraph in usable {
            let heading = paragraph.style.lowercased()
            let isTitle = heading.contains("title")
            let isHeading = isTitle || heading.contains("heading")
            let size: CGFloat = isTitle ? 22 : (isHeading ? 16 : 12.5)
            var traits: NSFontTraitMask = []
            if isHeading || paragraph.bold { traits.insert(.boldFontMask) }
            if paragraph.italic { traits.insert(.italicFontMask) }
            let font = NSFontManager.shared.convert(
                NSFont.systemFont(ofSize: size),
                toHaveTrait: traits
            )
            let mutableStyle = NSMutableParagraphStyle()
            mutableStyle.lineSpacing = isHeading ? 2 : 1.5
            mutableStyle.paragraphSpacing = isHeading ? 7 : 2
            if paragraph.bullet {
                mutableStyle.headIndent = 16
                mutableStyle.firstLineHeadIndent = 2
            }
            let prefix = paragraph.bullet ? "•  " : ""
            output.append(
                NSAttributedString(
                    string: prefix + paragraph.text + "\n",
                    attributes: [
                        .font: font,
                        .foregroundColor: NSColor.black,
                        .paragraphStyle: mutableStyle
                    ]
                )
            )
        }
        return output
    }
}

// MARK: - DOCX

private final class DOCXParser: NSObject, XMLParserDelegate {
    var paragraphs: [OfficeText.Paragraph] = []

    private var text = ""
    private var style = ""
    private var bold = false
    private var italic = false
    private var inText = false
    private var inParagraph = false
    private var bullet = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "w:p":
            text = ""
            style = ""
            bold = false
            italic = false
            bullet = false
            inParagraph = true
        case "w:numPr":
            bullet = true
        case "w:pStyle":
            style = attributeDict["w:val"] ?? attributeDict["val"] ?? ""
        case "w:b":
            bold = true
        case "w:i":
            italic = true
        case "w:t":
            inText = true
        case "w:tab":
            if inParagraph { text += "\t" }
        case "w:br":
            if inParagraph { text += "\n" }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inText { text += string }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "w:t":
            inText = false
        case "w:p":
            if inParagraph {
                paragraphs.append(
                    .init(
                        text: text,
                        style: style,
                        bold: bold,
                        italic: italic,
                        bullet: bullet || style.lowercased().contains("list")
                    )
                )
            }
            inParagraph = false
        case "w:tc":
            if inParagraph { text += "\t" }
        case "w:tr":
            if inParagraph { text += "\n" }
        default:
            break
        }
    }
}

// MARK: - ODT

private final class ODTParser: NSObject, XMLParserDelegate {
    var paragraphs: [OfficeText.Paragraph] = []

    private var text = ""
    private var style = ""
    private var bold = false
    private var italic = false
    private var inParagraph = false
    private var inSpan = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "text:h":
            beginParagraph(
                style: "heading",
                level: attributeDict["text:outline-level"] ?? "1"
            )
        case "text:p":
            beginParagraph(style: "", level: "")
        case "text:span":
            inSpan = true
            let spanStyle = attributeDict["text:style-name"] ?? ""
            if spanStyle.lowercased().contains("bold") { bold = true }
            if spanStyle.lowercased().contains("italic") { italic = true }
        case "text:s":
            let count = Int(attributeDict["text:c"] ?? "1") ?? 1
            if inParagraph { text += String(repeating: " ", count: min(count, 20)) }
        case "text:tab":
            if inParagraph { text += "\t" }
        case "text:line-break":
            if inParagraph { text += "\n" }
        case "table:table-cell":
            if inParagraph { text += "\t" }
        case "table:table-row":
            if inParagraph { text += "\n" }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inParagraph { text += string }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "text:span":
            inSpan = false
        case "text:h", "text:p":
            if inParagraph {
                paragraphs.append(
                    .init(text: text, style: style, bold: bold, italic: italic)
                )
            }
            inParagraph = false
            text = ""
            style = ""
            bold = false
            italic = false
        default:
            break
        }
    }

    private func beginParagraph(style: String, level: String) {
        if inParagraph {
            paragraphs.append(
                .init(text: text, style: self.style, bold: bold, italic: italic)
            )
        }
        self.style = style
        if !level.isEmpty { self.style = "heading" }
        text = ""
        bold = false
        italic = false
        inParagraph = true
    }
}
