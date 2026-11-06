import Foundation
import UniformTypeIdentifiers
import AppKit

// MARK: - File kinds

public enum FileKind: String, CaseIterable, Sendable {
    case image, pdf, document, slides, spreadsheet, audio, video, archive, subtitle, unknown

    /// Extension table first: UTType conformance is ambiguous for CSV (conforms
    /// to `.text` before `.spreadsheet`), DOCX (conforms to `.zip`), etc.
    public static func detect(_ url: URL) -> FileKind {
        switch url.pathExtension.lowercased() {
        case "pdf": return .pdf
        case "jpg", "jpeg", "png", "heic", "heif", "webp", "tiff", "tif", "bmp", "avif", "svg":
            return .image
        case "gif", "mp4", "mov", "m4v", "mkv", "webm", "avi", "wmv":
            return .video
        case "mp3", "m4a", "wav", "flac", "ogg", "opus", "aiff", "aif", "wma":
            return .audio
        case "csv", "tsv", "xlsx", "xls", "ods":
            return .spreadsheet
        case "zip", "tar", "gz", "gzip", "rar", "7z":
            return .archive
        case "srt", "vtt":
            return .subtitle
        case "pptx", "ppt", "odp":
            return .slides
        case "docx", "doc", "pages", "rtf", "rtfd", "textclipping", "txt", "md", "markdown", "epub", "html", "htm":
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

    public static func from(_ flags: NSEvent.ModifierFlags) -> WheelMode? {
        WheelShortcuts.mode(for: flags)
    }
}

public enum WheelShortcut: String, CaseIterable, Sendable {
    case shift, command, option, optionCommand, optionShift, control, controlOption, shiftCommand, shiftControl

    public var flags: NSEvent.ModifierFlags {
        switch self {
        case .shift: return .shift
        case .command: return .command
        case .option: return .option
        case .optionCommand: return [.option, .command]
        case .optionShift: return [.option, .shift]
        case .control: return .control
        case .controlOption: return [.control, .option]
        case .shiftCommand: return [.shift, .command]
        case .shiftControl: return [.shift, .control]
        }
    }

    public var title: String {
        switch self {
        case .shift: return "⇧ Shift"
        case .command: return "⌘ Command"
        case .option: return "⌥ Option"
        case .optionCommand: return "⌥⌘ Option + Command"
        case .optionShift: return "⇧⌥ Shift + Option"
        case .control: return "⌃ Control"
        case .controlOption: return "⌃⌥ Control + Option"
        case .shiftCommand: return "⇧⌘ Shift + Command"
        case .shiftControl: return "⇧⌃ Shift + Control"
        }
    }
}

/// Remembers the last wheel chosen during one drag. Releasing the modifier
/// does not clear it; starting a new drag resets it.
public struct WheelModeTracker {
    public private(set) var mode: WheelMode?

    public init() {}

    @discardableResult
    public mutating func update(modifiers: NSEvent.ModifierFlags) -> WheelMode? {
        if let next = WheelMode.from(modifiers) {
            mode = next
        }
        return mode
    }

    public mutating func reset() {
        mode = nil
    }
}

public enum WheelShortcuts {
    private static let convertKey = "wheelConvertShortcut"
    private static let toolsKey = "wheelToolsShortcut"
    private static let actionsKey = "wheelActionsShortcut"

    private static func read(_ key: String, fallback: WheelShortcut) -> WheelShortcut {
        WheelShortcut(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? fallback
    }

    public static var convert: WheelShortcut {
        get { read(convertKey, fallback: .shift) }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: convertKey) }
    }

    public static var tools: WheelShortcut {
        get { read(toolsKey, fallback: .optionShift) }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: toolsKey) }
    }

    public static var actions: WheelShortcut {
        get { read(actionsKey, fallback: .control) }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: actionsKey) }
    }

    /// Older builds defaulted Tools to Option+Command; migrate that one
    /// legacy value once so the shipping Tangerine shortcut is the default.
    public static func migrateLegacyDefaults() {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: toolsKey) == WheelShortcut.optionCommand.rawValue,
              defaults.object(forKey: "didMigrateToolsShortcut") == nil else {
            return
        }
        defaults.set(WheelShortcut.optionShift.rawValue, forKey: toolsKey)
        defaults.set(true, forKey: "didMigrateToolsShortcut")
    }

    /// Exact modifier match. Actions win over tools, tools over convert, so a
    /// duplicated binding still resolves deterministically.
    public static func mode(for flags: NSEvent.ModifierFlags) -> WheelMode? {
        let clean = flags.intersection(.deviceIndependentFlagsMask)
        if clean.contains(actions.flags) { return .actions }
        if clean.contains(tools.flags) { return .tools }
        if clean.contains(convert.flags) { return .convert }
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
            return convertItems(
                kinds: [kind],
                inputExtensions: inputExtension.map { [$0] } ?? []
            )
        case .tools:
            return tools(kind, fileCount: 1)
        case .actions:
            return actions
        }
    }

    public static func convertTargets(_ kind: FileKind) -> [String] {
        switch kind {
        case .image:
            return ["jpg", "png", "webp", "heic", "tiff", "avif", "bmp", "pdf"]
        case .pdf:
            return ["docx", "pages", "pptx", "xlsx", "jpg", "png", "tiff", "epub", "txt", "md"]
        case .document:
            return ["pdf", "docx", "pages", "md", "txt", "epub", "html", "jpg", "png"]
        case .slides:
            return ["pdf", "jpg", "png"]
        case .spreadsheet:
            return ["csv", "tsv", "xlsx", "ods", "pdf"]
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
                ("Read QR", "qrcode"),
                ("Edit", "slider.horizontal.3")
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
        case .document, .slides, .spreadsheet, .subtitle, .archive, .unknown:
            return []
        }
    }

    /// Tools that genuinely work on a multi-file selection today.
    public static func tools(_ kind: FileKind, fileCount: Int) -> [WheelItem] {
        let all = tools(kind)
        guard fileCount > 1 else {
            // Merge and collage need a selection. A single file should not
            // see a wedge that cannot do anything useful.
            return all.filter { $0.id != "tool:merge" && $0.id != "tool:collage" }
        }
        let allowed: Set<String>
        switch kind {
        case .image:
            allowed = ["tool:crop", "tool:collage"]
        case .pdf:
            allowed = ["tool:merge"]
        default:
            allowed = []
        }
        return all.filter { allowed.contains($0.id) }
    }

    /// Targets shared by every file in a selection, in the first kind's
    /// native order, excluding a format only when every input is already it.
    public static func convertItems(
        kinds: [FileKind],
        inputExtensions: [String]
    ) -> [WheelItem] {
        guard kinds.first != nil else { return [] }
        let lists = kinds.map(convertTargets)
        guard var intersection = lists.first.map(Set.init) else { return [] }
        for list in lists.dropFirst() {
            intersection.formIntersection(Set(list))
        }

        let own = Set(inputExtensions.map(normalisedExtension))
        let ordered = lists[0].filter { target in
            guard intersection.contains(target) else { return false }
            return !own.allSatisfy { $0 == target }
        }

        return Array(ordered.prefix(maxWedges)).map { target in
            WheelItem(id: "convert:\(target)", title: target.uppercased(), symbol: "")
        }
    }

    private static func normalisedExtension(_ ext: String) -> String {
        switch ext.lowercased() {
        case "jpeg": return "jpg"
        case "tif": return "tiff"
        case "heif": return "heic"
        default: return ext.lowercased()
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
