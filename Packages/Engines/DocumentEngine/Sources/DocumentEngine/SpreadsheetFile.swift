import Foundation
import JobCore

enum SpreadsheetFile {
    // MARK: XLSX writer

    static func writeXLSX(
        _ rows: [[String]],
        to url: URL,
        detectNumbers: Bool = true
    ) throws {
        let content = rows.isEmpty ? [[""]] : rows
        var zip = ZipWriter()

        zip.add("[Content_Types].xml", """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
        <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
        </Types>
        """)
        zip.add("_rels/.rels", """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """)
        zip.add("xl/workbook.xml", """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
                  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>
        </workbook>
        """)
        zip.add("xl/_rels/workbook.xml.rels", """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
        <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        </Relationships>
        """)
        zip.add("xl/styles.xml", """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        <fonts count="1"><font><sz val="11"/><name val="Helvetica"/></font></fonts>
        <fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>
        <borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
        <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
        <cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>
        <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
        </styleSheet>
        """)

        var sheetRows: [String] = []
        for (rowIndex, row) in content.enumerated() {
            let cells = row.enumerated().map { columnIndex, value in
                let reference = "\(columnName(columnIndex))\(rowIndex + 1)"
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if detectNumbers, isNumber(trimmed) {
                    return "<c r=\"\(reference)\"><v>\(trimmed)</v></c>"
                }
                return "<c r=\"\(reference)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(escape(value))</t></is></c>"
            }.joined()
            sheetRows.append("<row r=\"\(rowIndex + 1)\">\(cells)</row>")
        }

        zip.add("xl/worksheets/sheet1.xml", """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        <sheetData>\(sheetRows.joined())</sheetData>
        </worksheet>
        """)

        try writeAtomically(to: url) { temporary in
            try zip.write(to: temporary)
        }
    }

    // MARK: ODS writer

    static func writeODS(
        _ rows: [[String]],
        to url: URL,
        detectNumbers: Bool = true
    ) throws {
        let content = rows.isEmpty ? [[""]] : rows
        let body = content.map { row in
            let cells = row.map { value -> String in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if detectNumbers, isNumber(trimmed) {
                    return """
                    <table:table-cell office:value-type="float" office:value="\(trimmed)"><text:p>\(escape(trimmed))</text:p></table:table-cell>
                    """
                }
                return """
                <table:table-cell office:value-type="string"><text:p>\(escape(value))</text:p></table:table-cell>
                """
            }.joined()
            return "<table:table-row>\(cells)</table:table-row>"
        }.joined(separator: "\n")

        var zip = ZipWriter()
        zip.add("mimetype", "application/vnd.oasis.opendocument.spreadsheet")
        zip.add("META-INF/manifest.xml", """
        <?xml version="1.0" encoding="UTF-8"?>
        <manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.2">
        <manifest:file-entry manifest:full-path="/" manifest:media-type="application/vnd.oasis.opendocument.spreadsheet"/>
        <manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>
        </manifest:manifest>
        """)
        zip.add("content.xml", """
        <?xml version="1.0" encoding="UTF-8"?>
        <office:document-content
          xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
          xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0"
          xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
          office:version="1.2">
        <office:body><office:spreadsheet>
        <table:table table:name="Sheet1">
        \(body)
        </table:table>
        </office:spreadsheet></office:body>
        </office:document-content>
        """)

        try writeAtomically(to: url) { temporary in
            try zip.write(to: temporary)
        }
    }

    // MARK: XLSX reader

    static func readXLSX(_ url: URL) throws -> [[String]] {
        guard let archive = ZipReader(url: url) else {
            throw DocumentError.corrupt(url.lastPathComponent)
        }
        let shared = sharedStrings(archive)

        let sheetName: String
        if archive.contains("xl/worksheets/sheet1.xml") {
            sheetName = "xl/worksheets/sheet1.xml"
        } else if let first = archive.names.first(where: {
            $0.hasPrefix("xl/worksheets/") && $0.hasSuffix(".xml")
        }) {
            sheetName = first
        } else {
            throw DocumentError.corrupt(url.lastPathComponent)
        }
        guard let data = archive.read(sheetName) else {
            throw DocumentError.corrupt(url.lastPathComponent)
        }

        let delegate = SheetParser(sharedStrings: shared)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw DocumentError.corrupt(url.lastPathComponent)
        }
        return delegate.rows
    }

    private static func sharedStrings(_ archive: ZipReader) -> [String] {
        guard let data = archive.read("xl/sharedStrings.xml") else { return [] }
        let delegate = SharedStringsParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        _ = parser.parse()
        return delegate.values
    }

    // MARK: ODS reader

    static func readODS(_ url: URL) throws -> [[String]] {
        guard let archive = ZipReader(url: url),
              let data = archive.read("content.xml") else {
            throw DocumentError.corrupt(url.lastPathComponent)
        }
        let delegate = ODSParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse(), !delegate.rows.isEmpty else {
            throw DocumentError.corrupt(url.lastPathComponent)
        }
        return delegate.rows
    }

    // MARK: Helpers

    private static func isNumber(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        let pattern = #"^-?(0|[1-9][0-9]*)(\.[0-9]+)?$"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private static func columnName(_ index: Int) -> String {
        var value = index + 1
        var name = ""
        while value > 0 {
            let remainder = (value - 1) % 26
            name = String(UnicodeScalar(UInt8(65 + remainder))) + name
            value = (value - 1) / 26
        }
        return name
    }

    static func columnIndex(_ reference: String) -> Int? {
        var value = 0
        var found = false
        for scalar in reference.uppercased().unicodeScalars {
            guard scalar.value >= 65, scalar.value <= 90 else { break }
            value = value * 26 + Int(scalar.value) - 64
            found = true
        }
        return found ? value - 1 : nil
    }
}

// MARK: - XML delegates

private final class SharedStringsParser: NSObject, XMLParserDelegate {
    var values: [String] = []
    private var current = ""
    private var insideItem = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName == "si" {
            current = ""
            insideItem = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if insideItem { current += string }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "si" {
            values.append(current)
            insideItem = false
        }
    }
}

private final class SheetParser: NSObject, XMLParserDelegate {
    let sharedStrings: [String]
    var rows: [[String]] = []

    private var currentRow: [String] = []
    private var currentCellType = ""
    private var currentValue = ""
    private var insideValue = false
    private var insideInlineText = false
    private var currentColumn: Int?
    private var nextColumn = 0

    init(sharedStrings: [String]) {
        self.sharedStrings = sharedStrings
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "row":
            currentRow = []
            nextColumn = 0
        case "c":
            currentCellType = attributeDict["t"] ?? ""
            currentValue = ""
            currentColumn = attributeDict["r"].flatMap(SpreadsheetFile.columnIndex)
        case "v":
            insideValue = true
        case "t":
            if currentCellType == "inlineStr" {
                insideInlineText = true
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if insideValue || insideInlineText {
            currentValue += string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "v":
            insideValue = false
        case "t":
            insideInlineText = false
        case "c":
            let column = currentColumn ?? nextColumn
            while currentRow.count < column {
                currentRow.append("")
            }
            let value: String
            if currentCellType == "s" {
                let index = Int(currentValue.trimmingCharacters(in: .whitespaces)) ?? -1
                value = index >= 0 && index < sharedStrings.count
                    ? sharedStrings[index]
                    : ""
            } else if currentCellType == "b" {
                value = currentValue == "1" ? "TRUE" : "FALSE"
            } else {
                value = currentValue
            }
            if currentRow.count == column {
                currentRow.append(value)
            } else {
                currentRow[column] = value
            }
            nextColumn = column + 1
            currentColumn = nil
        case "row":
            rows.append(currentRow)
            currentRow = []
        default:
            break
        }
    }
}

private final class ODSParser: NSObject, XMLParserDelegate {
    var rows: [[String]] = []

    private var currentRow: [String] = []
    private var currentCell = ""
    private var insideText = false
    private var insideFirstTable = false
    private var finishedTable = false
    private var columnRepeat = 1
    private var rowRepeat = 1
    private var cellValue = ""
    private var cellIsNumber = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard !finishedTable else { return }
        switch elementName {
        case "table:table":
            insideFirstTable = true
        case "table:table-row":
            guard insideFirstTable else { return }
            currentRow = []
            rowRepeat = min(Int(attributeDict["table:number-rows-repeated"] ?? "1") ?? 1, 2_000)
        case "table:table-cell", "table:covered-table-cell":
            currentCell = ""
            cellValue = ""
            cellIsNumber = false
            insideText = false
            columnRepeat = min(Int(attributeDict["table:number-columns-repeated"] ?? "1") ?? 1, 500)
            if attributeDict["office:value-type"] != nil {
                cellIsNumber = true
                cellValue = attributeDict["office:value"]
                    ?? attributeDict["office:boolean-value"]
                    ?? ""
            }
        case "text:p":
            insideText = true
            if !currentCell.isEmpty { currentCell += "\n" }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if insideText { currentCell += string }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard !finishedTable else { return }
        switch elementName {
        case "text:p":
            insideText = false
        case "table:table-cell", "table:covered-table-cell":
            let value: String
            if !currentCell.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                value = currentCell
            } else if cellIsNumber {
                value = cellValue
            } else {
                value = ""
            }
            for _ in 0..<columnRepeat {
                currentRow.append(value)
            }
        case "table:table-row":
            guard insideFirstTable else { return }
            for _ in 0..<rowRepeat {
                rows.append(currentRow)
            }
        case "table:table":
            if insideFirstTable {
                finishedTable = true
            }
        default:
            break
        }
    }
}
