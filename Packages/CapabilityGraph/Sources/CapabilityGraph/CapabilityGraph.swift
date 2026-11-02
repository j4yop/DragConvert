import Foundation
import UniformTypeIdentifiers
import AppKit

// MARK: - File kinds

public enum FileKind: String, CaseIterable, Sendable {
    case image, pdf, document, spreadsheet, audio, video, archive, subtitle, unknown

    /// Extension table first: UTType conformance is ambiguous for CSV (conforms
    /// to `.text` before `.spreadsheet`), DOCX (conforms to `.zip`), etc.
    public static func detect(_ url: URL) -> FileKind {
        switch url.pathExtension.lowercased() {
        case "pdf": return .pdf
        case "jpg", "jpeg", "png", "heic", "heif", "webp", "tiff", "tif", "bmp", "avif", "gif", "svg":
            return .image
        case "mp4", "mov", "m4v", "mkv", "webm", "avi", "wmv":
            return .video
        case "mp3", "m4a", "wav", "flac", "ogg", "opus", "aiff", "aif", "wma":
            return .audio
        case "csv", "tsv", "xlsx", "xls", "ods":
            return .spreadsheet
        case "zip", "tar", "gz", "gzip", "rar", "7z":
            return .archive
        case "srt", "vtt":
            return .subtitle
        case "docx", "doc", "pages", "rtf", "rtfd", "txt", "md", "markdown", "epub", "pptx", "ppt", "html", "htm":
            return .document
        default:
            break
        }
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else {
            return .unknown
        }
        if type.conforms(to: .pdf) { return .pdf }
        if type.conforms(to: .image) { return .image }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
        if type.conforms(to: .audio) { return .audio }
        if type.conforms(to: .spreadsheet) { return .spreadsheet }
        if type.conforms(to: .archive) { return .archive }
        if type.conforms(to: .text) || type.conforms(to: .content) { return .document }
        return .unknown
    }

    public static func commonKind(of urls: [URL]) -> FileKind? {
        let kinds = Set(urls.map(detect))
        return kinds.count == 1 ? kinds.first : nil
    }
}

// MARK: - Wheel modes

public enum WheelMode: String, Sendable, CaseIterable {
    case convert, tools, actions

    /// Control wins over Shift, so a stray modifier can't pick the wrong wheel.
    public static func from(_ flags: NSEvent.ModifierFlags) -> WheelMode? {
        if flags.contains(.control) { return .actions }
        if flags.contains(.option) && flags.contains(.command) { return .tools }
        if flags.contains(.shift) { return .convert }
        return nil
    }
}

// MARK: - Wheel items

public struct WheelItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let symbol: String

    public init(id: String, title: String, symbol: String) {
        self.id = id
        self.title = title
        self.symbol = symbol
    }
}

// MARK: - The graph

public enum Capabilities {
    public static let maxWedges = 12

    public static func items(
        mode: WheelMode,
        kind: FileKind,
        inputExtension: String? = nil
    ) -> [WheelItem] {
        Array(allItems(mode: mode, kind: kind, inputExtension: inputExtension).prefix(maxWedges))
    }

    public static func allItems(
        mode: WheelMode,
        kind: FileKind,
        inputExtension: String? = nil
    ) -> [WheelItem] {
        switch mode {
        case .convert:
            let own = inputExtension?.lowercased()
            return convertTargets(kind)
                .filter { $0 != own }
                .map { WheelItem(id: "convert:\($0)", title: $0.uppercased(), symbol: "") }
        case .tools:
            return tools(kind)
        case .actions:
            return actions
        }
    }

    public static func convertTargets(_ kind: FileKind) -> [String] {
        switch kind {
        case .image:
            return ["jpg", "png", "webp", "heic", "tiff", "avif", "bmp", "pdf"]
        case .pdf:
            return ["docx", "pages", "pptx", "xlsx", "jpg", "png", "epub", "txt", "md"]
        case .document:
            return ["pdf", "docx", "pages", "md", "txt", "epub", "html"]
        case .spreadsheet:
            return ["csv", "tsv", "xlsx", "pdf"]
        case .audio:
            return ["mp3", "m4a", "wav", "flac", "ogg", "opus", "aiff", "wma"]
        case .video:
            return ["mp4", "mov", "mkv", "webm", "avi", "wmv", "gif", "mp3"]
        case .subtitle:
            return ["txt", "srt", "vtt"]
        case .archive:
            return ["zip", "tar", "gz"]
        case .unknown:
            return ["pdf", "jpg", "png"]
        }
    }

    public static func tools(_ kind: FileKind) -> [WheelItem] {
        func make(_ pairs: [(String, String)]) -> [WheelItem] {
            pairs.map { pair in
                let key = pair.0.lowercased().replacingOccurrences(of: " ", with: "")
                return WheelItem(id: "tool:\(key)", title: pair.0.uppercased(), symbol: pair.1)
            }
        }
        switch kind {
        case .image:
            return make([
                ("Compress", "arrow.down.right.and.arrow.up.left"),
                ("Crop", "crop"),
                ("Resize", "arrow.up.left.and.arrow.down.right"),
                ("Rotate", "rotate.right"),
                ("Annotate", "pencil.and.outline"),
                ("Add BG", "photo"),
                ("Redact", "eye.slash"),
                ("Remove BG", "person.crop.circle"),
                ("Metadata", "tag"),
                ("Collage", "square.grid.2x2"),
                ("Read QR", "qrcode")
            ])
        case .pdf:
            return make([
                ("Compress", "arrow.down.right.and.arrow.up.left"),
                ("Crop", "crop"),
                ("Annotate", "pencil.and.outline"),
                ("Redact", "eye.slash"),
                ("Add BG", "photo"),
                ("Metadata", "tag"),
                ("Merge", "doc.on.doc"),
                ("Organize", "rectangle.3.group"),
                ("Split", "scissors")
            ])
        case .video:
            return make([
                ("Trim", "scissors"),
                ("Crop", "crop"),
                ("Speed", "speedometer"),
                ("Join", "link"),
                ("Split", "square.split.2x1"),
                ("Snapshot", "camera"),
                ("Redact", "eye.slash")
            ])
        case .audio:
            return make([
                ("Normalize", "waveform"),
                ("Trim", "scissors"),
                ("Channels", "slider.horizontal.2.square"),
                ("Bleep", "speaker.slash"),
                ("Visualizer", "waveform.path.ecg")
            ])
        case .document, .spreadsheet, .subtitle, .archive, .unknown:
            return make([("Compress", "arrow.down.right.and.arrow.up.left")])
        }
    }

    public static let actions: [WheelItem] = [
        WheelItem(id: "action:airdrop", title: "AIRDROP", symbol: "antenna.radiowaves.left.and.right"),
        WheelItem(id: "action:float", title: "FLOAT", symbol: "macwindow.on.rectangle"),
        WheelItem(id: "action:copy", title: "COPY", symbol: "doc.on.doc"),
        WheelItem(id: "action:move", title: "MOVE", symbol: "folder"),
        WheelItem(id: "action:copypath", title: "COPY PATH", symbol: "link"),
        WheelItem(id: "action:terminal", title: "TERMINAL", symbol: "terminal")
    ]
}
