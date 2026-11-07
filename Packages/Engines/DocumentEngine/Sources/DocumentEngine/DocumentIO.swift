import AppKit
import Foundation

enum DocumentIO {
    static func load(_ url: URL) throws -> NSAttributedString {
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "txt", "md", "markdown":
            let data = try Data(contentsOf: url)
            let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1)
                ?? ""
            return plain(text)

        case "rtf":
            return try attributed(url, type: .rtf, name: url.lastPathComponent)

        case "rtfd":
            return try attributed(url, type: .rtfd, name: url.lastPathComponent)

        case "html", "htm":
            let data = try Data(contentsOf: url)
            return try html(data, baseURL: url.deletingLastPathComponent(), name: url.lastPathComponent)

        case "webarchive":
            return try attributed(url, type: .webArchive, name: url.lastPathComponent)

        case "docx":
            return try OfficeText.loadDOCX(url)

        case "odt":
            return try OfficeText.loadODT(url)

        case "epub":
            return try epub(url)

        default:
            throw DocumentError.unsupported(".\(ext)")
        }
    }

    static func plain(_ text: String) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: 12.5),
                .foregroundColor: NSColor.black
            ]
        )
    }

    static func html(
        _ data: Data,
        baseURL: URL?,
        name: String
    ) throws -> NSAttributedString {
        var options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        if let baseURL {
            options[.baseURL] = baseURL
        }
        do {
            return try NSAttributedString(
                data: data,
                options: options,
                documentAttributes: nil
            )
        } catch {
            throw DocumentError.corrupt(name)
        }
    }

    static func plainText(_ attributed: NSAttributedString) -> String {
        attributed.string
            .replacingOccurrences(of: "\u{FFFC}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func attributed(
        _ url: URL,
        type: NSAttributedString.DocumentType,
        name: String
    ) throws -> NSAttributedString {
        do {
            return try NSAttributedString(
                url: url,
                options: [.documentType: type],
                documentAttributes: nil
            )
        } catch {
            throw DocumentError.corrupt(name)
        }
    }

    private static func epub(_ url: URL) throws -> NSAttributedString {
        guard let archive = ZipReader(url: url) else {
            throw DocumentError.corrupt(url.lastPathComponent)
        }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        var htmlFiles: [String] = []
        for name in archive.names where !name.hasSuffix("/") {
            let components = name.split(separator: "/")
            guard !components.contains("..") else { continue }
            guard let data = archive.read(name) else { continue }
            let destination = directory.appendingPathComponent(name)
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: destination)
            let lowered = name.lowercased()
            let base = (name as NSString).lastPathComponent.lowercased()
            if base == "nav.xhtml" || base == "toc.xhtml" { continue }
            if lowered.hasSuffix(".xhtml") || lowered.hasSuffix(".html")
                || lowered.hasSuffix(".htm") {
                htmlFiles.append(name)
            }
        }

        htmlFiles.sort()
        guard !htmlFiles.isEmpty else {
            throw DocumentError.corrupt(url.lastPathComponent)
        }

        let combined = NSMutableAttributedString()
        for (index, name) in htmlFiles.enumerated() {
            let file = directory.appendingPathComponent(name)
            guard let data = try? Data(contentsOf: file) else { continue }
            if let part = try? html(
                data,
                baseURL: file.deletingLastPathComponent(),
                name: name
            ) {
                if index > 0 {
                    combined.append(NSAttributedString(string: "\n"))
                }
                combined.append(part)
            }
        }
        guard combined.length > 0 else {
            throw DocumentError.corrupt(url.lastPathComponent)
        }
        return combined
    }
}
