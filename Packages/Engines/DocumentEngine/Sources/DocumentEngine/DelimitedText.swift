import Foundation

enum DelimitedText {
    static func parse(_ text: String, separator: Character) -> [[String]] {
        // CRLF is one extended grapheme cluster in Swift, so normalize before
        // iterating or every Windows CSV would collapse into a single row.
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let characters = Array(normalized)
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var index = 0

        func finishField() {
            row.append(field)
            field = ""
        }

        func finishRow() {
            finishField()
            rows.append(row)
            row = []
        }

        while index < characters.count {
            let character = characters[index]

            if inQuotes {
                if character == "\"" {
                    if index + 1 < characters.count,
                       characters[index + 1] == "\"" {
                        field.append("\"")
                        index += 2
                    } else {
                        inQuotes = false
                        index += 1
                    }
                } else {
                    field.append(character)
                    index += 1
                }
                continue
            }

            switch character {
            case "\"":
                inQuotes = true
                index += 1
            case separator:
                finishField()
                index += 1
            case "\n":
                finishRow()
                index += 1
            case "\r":
                if index + 1 < characters.count, characters[index + 1] == "\n" {
                    index += 1
                }
                finishRow()
                index += 1
            default:
                field.append(character)
                index += 1
            }
        }

        if !field.isEmpty || !row.isEmpty {
            finishRow()
        }

        if let last = rows.last, last.count == 1, last[0].isEmpty {
            rows.removeLast()
        }
        return rows
    }

    static func encode(_ rows: [[String]], separator: Character) -> String {
        rows.map { row in
            row.map { field in
                let needsQuotes = field.contains(separator)
                    || field.contains("\"")
                    || field.contains("\n")
                    || field.contains("\r")
                if !needsQuotes { return field }
                return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }.joined(separator: String(separator))
        }.joined(separator: "\r\n") + "\r\n"
    }

    static func read(_ url: URL) throws -> [[String]] {
        let data = try Data(contentsOf: url)
        var text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        let separator: Character = url.pathExtension.lowercased() == "tsv" ? "\t" : ","
        return parse(text, separator: separator)
    }
}
