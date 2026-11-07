import AppKit
import Foundation
import JobCore

enum DocumentWriters {
    // MARK: Text

    static func writeText(_ pages: [String], to url: URL) throws {
        let body = pages
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        try writeAtomically(to: url) { temporary in
            try (body + "\n").data(using: .utf8)?.write(to: temporary, options: .atomic)
        }
    }

    static func writeMarkdown(_ pages: [String], title: String, to url: URL) throws {
        let body = pages
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        try writeAtomically(to: url) { temporary in
            let content = "# \(title)\n\n\(body)\n"
            try content.data(using: .utf8)?.write(to: temporary, options: .atomic)
        }
    }

    // MARK: HTML

    static func writeHTML(_ pages: [String], title: String, to url: URL) throws {
        let body = pages.enumerated().map { index, page in
            let paragraphs = page
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .map { "<p>\(htmlEscape($0))</p>" }
                .joined(separator: "\n")
            return """
            <section class="page" id="page-\(index + 1)">
            \(paragraphs)
            </section>
            """
        }.joined(separator: "\n")

        let html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(htmlEscape(title))</title>
        <style>
        body { font: 16px/1.55 -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
               color: #111; max-width: 46rem; margin: 3rem auto; padding: 0 1.5rem; }
        h1 { font-size: 1.65rem; margin: 0 0 2rem; }
        section.page { border-bottom: 1px solid #ddd; margin-bottom: 2rem; padding-bottom: 1rem; }
        section.page:last-child { border-bottom: 0; }
        p { margin: 0 0 0.85rem; white-space: pre-wrap; }
        </style>
        </head>
        <body>
        <h1>\(htmlEscape(title))</h1>
        \(body)
        </body>
        </html>
        """

        try writeAtomically(to: url) { temporary in
            try html.data(using: .utf8)?.write(to: temporary, options: .atomic)
        }
    }

    // MARK: RTF / RTFD

    static func writeRTF(_ pages: [String], title: String, to url: URL) throws {
        let content = rtfDocument(pages: pages, title: title)
        try writeAtomically(to: url) { temporary in
            try content.data(using: .utf8)?.write(to: temporary, options: .atomic)
        }
    }

    static func writeRTFD(_ pages: [String], title: String, to url: URL) throws {
        let file = url.appendingPathComponent("TXT.rtf")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try rtfDocument(pages: pages, title: title)
            .data(using: .utf8)?
            .write(to: file, options: .atomic)
    }

    private static func rtfDocument(pages: [String], title: String) -> String {
        let body = pages.enumerated().map { index, page in
            let prefix = index == 0 ? "" : "\\page\n"
            return prefix + rtfEscape(page)
        }.joined(separator: "\n")
        return """
        {\\rtf1\\ansi\\ansicpg1252\\deff0
        {\\fonttbl{\\f0\\fswiss Helvetica;}{\\f1\\fswiss Helvetica-Bold;}}
        \\fs26
        {\\f1\\fs32 \(rtfEscape(title))\\par}
        \\fs26\\par
        \(body)
        }
        """
    }

    private static func rtfEscape(_ text: String) -> String {
        var output = ""
        for unit in text.utf16 {
            switch unit {
            case 0x0A:
                output += "\\par\n"
            case 0x0D:
                continue
            case 0x5C:
                output += "\\\\"
            case 0x7B:
                output += "\\{"
            case 0x7D:
                output += "\\}"
            case 0x09:
                output += "\\tab "
            default:
                if unit < 128 {
                    output.append(Character(UnicodeScalar(UInt8(unit))))
                } else {
                    let signed = unit >= 0x8000 ? Int(unit) - 65_536 : Int(unit)
                    output += "\\u\(signed)?"
                }
            }
        }
        return output
    }

    // MARK: DOCX

    static func writeDOCX(_ pages: [String], title: String, to url: URL) throws {
        var zip = ZipWriter()
        zip.add("[Content_Types].xml", """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        </Types>
        """)
        zip.add("_rels/.rels", """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """)

        var paragraphs: [String] = []
        for (pageIndex, page) in pages.enumerated() {
            if pageIndex > 0 {
                paragraphs.append("<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>")
            }
            for line in page.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else {
                    paragraphs.append("<w:p/>")
                    continue
                }
                paragraphs.append("""
                <w:p><w:r><w:t xml:space="preserve">\(xmlEscape(trimmed))</w:t></w:r></w:p>
                """)
            }
        }

        zip.add("word/document.xml", """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
        \(paragraphs.joined(separator: "\n"))
        <w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr>
        </w:body>
        </w:document>
        """)

        try writeAtomically(to: url) { temporary in
            try zip.write(to: temporary)
        }
    }

    // MARK: EPUB

    static func writeEPUB(_ pages: [String], title: String, to url: URL) throws {
        let identifier = "urn:uuid:\(UUID().uuidString)"
        let chapters = pages.enumerated().map { index, page in
            (
                "chapter\(index + 1).xhtml",
                xhtmlDocument(
                    title: "\(title) — \(index + 1)",
                    body: xhtmlBody(page)
                )
            )
        }

        var manifest = ""
        var spine = ""
        var navigation = ""
        for (index, chapter) in chapters.enumerated() {
            let id = "chapter\(index + 1)"
            manifest += """
            <item id="\(id)" href="\(chapter.0)" media-type="application/xhtml+xml"/>

            """
            spine += "<itemref idref=\"\(id)\"/>\n"
            navigation += """
            <li><a href="\(chapter.0)">Page \(index + 1)</a></li>

            """
        }

        let opf = """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid">
        <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:identifier id="bookid">\(identifier)</dc:identifier>
        <dc:title>\(xmlEscape(title))</dc:title>
        <dc:language>en</dc:language>
        <meta property="dcterms:modified">\(isoDate())</meta>
        </metadata>
        <manifest>
        <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
        \(manifest)
        </manifest>
        <spine>
        \(spine)
        </spine>
        </package>
        """

        var zip = ZipWriter()
        zip.add("mimetype", "application/epub+zip")
        zip.add("META-INF/container.xml", """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
        <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
        </container>
        """)
        zip.add("OEBPS/content.opf", opf)
        zip.add("OEBPS/nav.xhtml", xhtmlDocument(
            title: title,
            body: "<nav epub:type=\"toc\" id=\"toc\"><h1>\(xhtmlEscape(title))</h1><ol>\(navigation)</ol></nav>",
            extraNamespace: " xmlns:epub=\"http://www.idpf.org/2007/ops\""
        ))
        for chapter in chapters {
            zip.add("OEBPS/\(chapter.0)", chapter.1)
        }

        try writeAtomically(to: url) { temporary in
            try zip.write(to: temporary)
        }
    }

    private static func xhtmlDocument(
        title: String,
        body: String,
        extraNamespace: String = ""
    ) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml"\(extraNamespace) lang="en" xml:lang="en">
        <head><meta charset="utf-8"/><title>\(xhtmlEscape(title))</title>
        <style>body{font:16px/1.55 -apple-system,Helvetica,sans-serif;margin:6%;color:#111}p{margin:0 0 .8em;white-space:pre-wrap}</style>
        </head>
        <body>\(body)</body>
        </html>
        """
    }

    private static func xhtmlBody(_ text: String) -> String {
        text.components(separatedBy: "\n").map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { return "<p>&#160;</p>" }
            return "<p>\(xhtmlEscape(trimmed))</p>"
        }.joined(separator: "\n")
    }

    // MARK: Escaping

    static func xmlEscape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    static func htmlEscape(_ text: String) -> String {
        xmlEscape(text)
    }

    static func xhtmlEscape(_ text: String) -> String {
        xmlEscape(text)
    }

    private static func isoDate() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: Date())
    }
}
