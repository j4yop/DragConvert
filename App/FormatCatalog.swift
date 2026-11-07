import Foundation

enum FormatCategory: String, CaseIterable, Identifiable {
    case images, documents, spreadsheets, audio, video, archives, subtitles

    var id: String { rawValue }

    var title: String {
        switch self {
        case .images: return "Images"
        case .documents: return "Documents"
        case .spreadsheets: return "Spreadsheets"
        case .audio: return "Audio"
        case .video: return "Video"
        case .archives: return "Archives"
        case .subtitles: return "Subtitles"
        }
    }

    var symbol: String {
        switch self {
        case .images: return "photo.on.rectangle.angled"
        case .documents: return "doc.text"
        case .spreadsheets: return "tablecells"
        case .audio: return "waveform"
        case .video: return "film"
        case .archives: return "archivebox"
        case .subtitles: return "captions.bubble"
        }
    }
}

struct FormatSettings: Hashable {
    var quality = false
    var metadata = false
    var imageCompression = false
    var pdfLayout = false
    var audioBitrate = false
    var audioDepth = false
    var videoQuality = false
    var videoHeight = false
    var videoCompression = false
    var archiveCompression = false
    var gifOptions = false
    var epubLayout = false
    var spreadsheetOptions = false
    var spreadsheetNumbers = false

    var any: Bool {
        quality || metadata || imageCompression || pdfLayout
            || audioBitrate || audioDepth || videoQuality || videoHeight
            || videoCompression || archiveCompression || gifOptions
            || epubLayout || spreadsheetOptions || spreadsheetNumbers
    }
}

struct FormatSpec: Identifiable, Hashable {
    let id: String
    let name: String
    let category: FormatCategory
    let input: Bool
    let outputs: [String]
    let settings: FormatSettings
    let extensions: [String]

    var isInputOnly: Bool { input && outputs.isEmpty }
    var isOutputOnly: Bool { !input && !outputs.isEmpty }
    var isUnavailable: Bool { !input && outputs.isEmpty }

    var description: String {
        if isInputOnly { return "Input-only format." }
        if isOutputOnly { return "Output-only format." }
        if isUnavailable { return "Unavailable for conversion." }
        let names = outputs.map { FormatCatalog.displayName($0) }
        let list: String
        switch names.count {
        case 0: list = ""
        case 1: list = names[0]
        case 2: list = "\(names[0]) and \(names[1])"
        default:
            list = names.dropLast().joined(separator: ", ") + ", and " + names.last!
        }
        return "Input and output format. Converts to \(list)."
    }
}

enum FormatCatalog {
    static let all: [FormatSpec] = images + documents + spreadsheets + audio + video + archives + subtitles

    static let images: [FormatSpec] = [
        spec("jpg", "JPG", .images, input: true,
             outputs: ["png", "webp", "heic", "tiff", "avif", "bmp", "pdf"],
             settings: .init(quality: true, metadata: true, imageCompression: true),
             ext: ["jpg", "jpeg"]),
        spec("png", "PNG", .images, input: true,
             outputs: ["jpg", "webp", "heic", "tiff", "avif", "bmp", "pdf"],
             settings: .init(metadata: true, imageCompression: true),
             ext: ["png"]),
        spec("webp", "WEBP", .images, input: true,
             outputs: ["jpg", "png", "heic", "tiff", "avif", "bmp", "pdf"],
             settings: .init(quality: true, metadata: true),
             ext: ["webp"]),
        spec("heic", "HEIC", .images, input: true,
             outputs: ["jpg", "png", "webp", "tiff", "avif", "bmp", "pdf"],
             settings: .init(quality: true, metadata: true),
             ext: ["heic", "heif"]),
        spec("tiff", "TIFF", .images, input: true,
             outputs: ["jpg", "png", "webp", "heic", "avif", "bmp", "pdf"],
             settings: .init(metadata: true),
             ext: ["tiff", "tif"]),
        spec("svg", "SVG", .images, input: true,
             outputs: ["jpg", "png", "webp", "heic", "tiff", "avif", "bmp", "pdf"],
             settings: .init(),
             ext: ["svg"]),
        spec("avif", "AVIF", .images, input: true,
             outputs: ["jpg", "png", "webp", "heic", "tiff", "bmp", "pdf"],
             settings: .init(quality: true, metadata: true),
             ext: ["avif"]),
        spec("bmp", "BMP", .images, input: true,
             outputs: ["jpg", "png", "webp", "heic", "tiff", "avif", "pdf"],
             settings: .init(),
             ext: ["bmp"]),
        spec("raw", "RAW", .images, input: true,
             outputs: ["jpg", "png", "webp", "heic", "tiff", "avif", "bmp", "pdf"],
             settings: .init(),
             ext: ["dng", "cr2", "cr3", "nef", "arw", "raf", "orf", "rw2"])
    ]

    static let documents: [FormatSpec] = [
        spec("pdf", "PDF", .documents, input: true,
             outputs: ["docx", "pages", "pptx", "xlsx", "jpg", "png", "tiff", "epub", "txt", "md"],
             settings: .init(pdfLayout: true),
             ext: ["pdf"]),
        spec("docx", "DOCX", .documents, input: true,
             outputs: ["pages", "pdf", "txt", "md", "html", "epub", "png", "jpg"],
             settings: .init(pdfLayout: true),
             ext: ["docx", "doc"]),
        spec("pages", "PAGES", .documents, input: true,
             outputs: ["docx", "pdf", "txt", "md", "html", "epub", "png", "jpg"],
             settings: .init(pdfLayout: true),
             ext: ["pages"]),
        spec("ppt", "PPT", .documents, input: true,
             outputs: ["pdf", "jpg", "png"],
             settings: .init(pdfLayout: true),
             ext: ["ppt"]),
        spec("pptx", "PPTX", .documents, input: true,
             outputs: ["pdf", "jpg", "png"],
             settings: .init(pdfLayout: true),
             ext: ["pptx"]),
        spec("txt", "TXT", .documents, input: true,
             outputs: ["pdf", "docx", "pages", "html", "epub", "png", "jpg"],
             settings: .init(pdfLayout: true),
             ext: ["txt"]),
        spec("md", "MD", .documents, input: true,
             outputs: ["pdf", "docx", "pages", "txt", "html", "epub", "png", "jpg"],
             settings: .init(pdfLayout: true),
             ext: ["md", "markdown"]),
        spec("rtf", "RTF", .documents, input: true,
             outputs: ["pdf", "docx", "pages", "txt", "md", "html", "epub", "png", "jpg"],
             settings: .init(pdfLayout: true),
             ext: ["rtf"]),
        spec("rtfd", "RTFD", .documents, input: true,
             outputs: ["pdf", "docx", "pages", "txt", "md", "html", "epub", "png", "jpg"],
             settings: .init(pdfLayout: true),
             ext: ["rtfd"]),
        spec("textclipping", "TEXTCLIPPING", .documents, input: true,
             outputs: ["pdf", "docx", "pages", "txt", "md", "html", "epub", "png", "jpg"],
             settings: .init(pdfLayout: true),
             ext: ["textclipping"]),
        spec("html", "HTML", .documents, input: true,
             outputs: ["pdf", "docx", "pages", "txt", "md", "epub", "png", "jpg"],
             settings: .init(pdfLayout: true),
             ext: ["html", "htm"]),
        spec("epub", "EPUB", .documents, input: true,
             outputs: ["pdf", "docx", "pages", "txt", "md", "html", "png", "jpg"],
             settings: .init(pdfLayout: true, epubLayout: true),
             ext: ["epub"])
    ]

    static let spreadsheets: [FormatSpec] = [
        spec("xlsx", "XLSX", .spreadsheets, input: true,
             outputs: ["ods", "csv", "tsv", "pdf"], settings: .init(spreadsheetNumbers: true), ext: ["xlsx"]),
        spec("xls", "XLS", .spreadsheets, input: true,
             outputs: ["xlsx", "ods", "csv", "tsv", "pdf"], settings: .init(spreadsheetNumbers: true), ext: ["xls"]),
        spec("ods", "ODS", .spreadsheets, input: true,
             outputs: ["xlsx", "xls", "csv", "tsv", "pdf"], settings: .init(spreadsheetNumbers: true), ext: ["ods"]),
        spec("csv", "CSV", .spreadsheets, input: true,
             outputs: ["xlsx", "xls", "ods", "tsv", "pdf"], settings: .init(spreadsheetNumbers: true), ext: ["csv"]),
        spec("tsv", "TSV", .spreadsheets, input: true,
             outputs: ["xlsx", "xls", "ods", "csv", "pdf"], settings: .init(spreadsheetNumbers: true), ext: ["tsv"])
    ]

    static let audio: [FormatSpec] = [
        spec("mp3", "MP3", .audio, input: true,
             outputs: ["m4a", "wav", "flac", "ogg", "opus", "aiff", "wma"],
             settings: .init(audioBitrate: true), ext: ["mp3"]),
        spec("m4a", "M4A", .audio, input: true,
             outputs: ["mp3", "wav", "flac", "ogg", "opus", "aiff", "wma"],
             settings: .init(audioBitrate: true), ext: ["m4a"]),
        spec("wav", "WAV", .audio, input: true,
             outputs: ["mp3", "m4a", "flac", "ogg", "opus", "aiff", "wma"],
             settings: .init(audioDepth: true), ext: ["wav"]),
        spec("flac", "FLAC", .audio, input: true,
             outputs: ["mp3", "m4a", "wav", "ogg", "opus", "aiff", "wma"],
             settings: .init(audioDepth: true), ext: ["flac"]),
        spec("ogg", "OGG", .audio, input: true,
             outputs: ["mp3", "m4a", "wav", "flac", "opus", "aiff", "wma"],
             settings: .init(audioBitrate: true), ext: ["ogg"]),
        spec("opus", "OPUS", .audio, input: true,
             outputs: ["mp3", "m4a", "wav", "flac", "ogg", "aiff", "wma"],
             settings: .init(audioBitrate: true), ext: ["opus"]),
        spec("aiff", "AIFF", .audio, input: true,
             outputs: ["mp3", "m4a", "wav", "flac", "ogg", "opus", "wma"],
             settings: .init(audioDepth: true), ext: ["aiff", "aif"]),
        spec("wma", "WMA", .audio, input: true,
             outputs: ["mp3", "m4a", "wav", "flac", "ogg", "opus", "aiff"],
             settings: .init(audioBitrate: true), ext: ["wma"])
    ]

    static let video: [FormatSpec] = [
        spec("mp4", "MP4", .video, input: true,
             outputs: ["mov", "m4v", "m4a", "gif", "mkv", "webm", "avi", "wmv"],
             settings: .init(videoQuality: true, videoHeight: true, videoCompression: true), ext: ["mp4"]),
        spec("mov", "MOV", .video, input: true,
             outputs: ["mp4", "m4v", "m4a", "gif", "mkv", "webm", "avi", "wmv"],
             settings: .init(videoQuality: true, videoHeight: true, videoCompression: true), ext: ["mov"]),
        spec("m4v", "M4V", .video, input: true,
             outputs: ["mp4", "mov", "m4a", "gif", "mkv", "webm", "avi", "wmv"],
             settings: .init(videoQuality: true, videoHeight: true, videoCompression: true), ext: ["m4v"]),
        spec("mkv", "MKV", .video, input: true,
             outputs: ["mp4", "mov", "m4v", "m4a", "gif", "webm", "avi", "wmv"],
             settings: .init(videoQuality: true, videoHeight: true, videoCompression: true), ext: ["mkv"]),
        spec("webm", "WEBM", .video, input: true,
             outputs: ["mp4", "mov", "m4v", "m4a", "gif", "mkv", "avi", "wmv"],
             settings: .init(videoQuality: true, videoHeight: true, videoCompression: true), ext: ["webm"]),
        spec("avi", "AVI", .video, input: true,
             outputs: ["mp4", "mov", "m4v", "m4a", "gif", "mkv", "webm", "wmv"],
             settings: .init(videoQuality: true, videoHeight: true, videoCompression: true), ext: ["avi"]),
        spec("wmv", "WMV", .video, input: true,
             outputs: ["mp4", "mov", "m4v", "m4a", "gif", "mkv", "webm", "avi"],
             settings: .init(videoQuality: true, videoHeight: true, videoCompression: true), ext: ["wmv"]),
        spec("gif", "GIF", .video, input: true,
             outputs: ["mp4", "mov", "m4v", "m4a", "mkv", "webm", "avi", "wmv"],
             settings: .init(gifOptions: true), ext: ["gif"])
    ]

    static let archives: [FormatSpec] = [
        spec("zip", "ZIP", .archives, input: true,
             outputs: ["tar", "gz"], settings: .init(archiveCompression: true), ext: ["zip"]),
        spec("tar", "TAR", .archives, input: true,
             outputs: ["zip", "gz"], settings: .init(archiveCompression: true), ext: ["tar"]),
        spec("gz", "GZIP", .archives, input: true,
             outputs: ["zip", "tar"], settings: .init(archiveCompression: true), ext: ["gz", "gzip"]),
        spec("rar", "RAR", .archives, input: true,
             outputs: ["zip", "tar", "gz"], settings: .init(archiveCompression: true), ext: ["rar"])
    ]

    static let subtitles: [FormatSpec] = [
        spec("srt", "SRT", .subtitles, input: true,
             outputs: ["vtt", "txt"], settings: .init(), ext: ["srt"]),
        spec("vtt", "VTT", .subtitles, input: true,
             outputs: ["srt", "txt"], settings: .init(), ext: ["vtt"])
    ]

    static func spec(
        _ id: String,
        _ name: String,
        _ category: FormatCategory,
        input: Bool,
        outputs: [String],
        settings: FormatSettings,
        ext: [String]
    ) -> FormatSpec {
        FormatSpec(
            id: id, name: name, category: category, input: input,
            outputs: outputs, settings: settings, extensions: ext
        )
    }

    static func format(_ id: String) -> FormatSpec? {
        all.first { $0.id == id.lowercased() }
    }

    static func displayName(_ id: String) -> String {
        format(id)?.name ?? id.uppercased()
    }

    static func inCategory(_ category: FormatCategory) -> [FormatSpec] {
        all.filter { $0.category == category }
    }

    /// Reference matrix columns shown on the Compatibility tab.
    static let matrixColumns: [FormatCategory: [String]] = [
        .images: ["jpg", "png", "webp", "heic", "tiff", "avif", "bmp", "pdf"],
        .documents: ["pdf", "docx", "pages", "pptx", "txt", "md", "html", "epub", "jpg", "png", "svg", "xlsx"],
        .spreadsheets: ["xlsx", "ods", "csv", "tsv", "pdf"],
        .audio: ["mp3", "m4a", "wav", "flac", "ogg", "opus", "aiff", "wma"],
        .video: ["mp4", "mov", "mkv", "webm", "avi", "wmv", "gif", "mp3"],
        .archives: ["zip", "tar", "gz"],
        .subtitles: ["srt", "vtt", "txt"]
    ]
}

struct FormatProfileValues: Equatable {
    var quality = "balanced"
    var preserveMetadata = true
    var imageCompression = "balanced"
    var imageSize = "original"
    var pdfLayout = "editable"
    var audioBitrate = "256 kbps"
    var audioDepth = "matchSource"
    var videoQuality = "balanced"
    var videoMaxHeight = "original"
    var videoCompression = "balanced"
    var archiveCompression = "balanced"
    var gifFrameRate = "original"
    var gifMaxWidth = "original"
    var epubLayout = "editable"
    var spreadsheetNumbers = true
}
