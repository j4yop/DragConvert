import SwiftUI
import AppKit
import CapabilityGraph

struct MoreTool: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
}

private enum MoreToolCatalog {
    static func tools(for kind: FileKind) -> [MoreTool] {
        switch kind {
        case .image:
            return [
                MoreTool(
                    id: "tool:annotate",
                    title: "Annotate",
                    detail: "Text, shapes and ink",
                    symbol: "pencil.tip.crop.circle"
                ),
                MoreTool(
                    id: "tool:addbg",
                    title: "Add Background",
                    detail: "Frame on a colour",
                    symbol: "rectangle.inset.filled"
                ),
                MoreTool(
                    id: "tool:removebg",
                    title: "Remove Background",
                    detail: "Transparent PNG",
                    symbol: "person.crop.rectangle"
                ),
                MoreTool(
                    id: "tool:edit",
                    title: "Photo Editor",
                    detail: "Colour and adjustments",
                    symbol: "slider.horizontal.3"
                ),
                MoreTool(
                    id: "tool:readqr",
                    title: "Read QR",
                    detail: "Find QR content",
                    symbol: "qrcode.viewfinder"
                )
            ]
        case .pdf:
            return [
                MoreTool(
                    id: "tool:annotate",
                    title: "Annotate",
                    detail: "Mark up and save a copy",
                    symbol: "pencil.tip.crop.circle"
                ),
                MoreTool(
                    id: "tool:redact",
                    title: "Redact",
                    detail: "Black out areas",
                    symbol: "eye.slash"
                ),
                MoreTool(
                    id: "tool:addbg",
                    title: "Add Background",
                    detail: "Place pages on a colour",
                    symbol: "rectangle.inset.filled"
                ),
                MoreTool(
                    id: "tool:crop",
                    title: "Crop Pages",
                    detail: "Trim every page",
                    symbol: "crop"
                )
            ]
        default:
            return []
        }
    }
}

struct MoreToolsView: View {
    let heading: String
    let sourceName: String
    let tools: [MoreTool]
    let footnote: String
    let onSelect: (String) -> Void

    @State private var hovered: String?

    private let accent = Color(red: 1.0, green: 0.322, blue: 0.0)
    private let panel = Color(white: 0.155)

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(accent.opacity(0.14))
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(heading)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.94))
                    Text(sourceName)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.white.opacity(0.45))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(tools) { tool in
                    Button {
                        onSelect(tool.id)
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: tool.symbol)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(hovered == tool.id ? accent : Color.white.opacity(0.72))
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(tool.title)
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.92))
                                Text(tool.detail)
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(Color.white.opacity(0.40))
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 52)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(hovered == tool.id ? Color.white.opacity(0.09) : panel)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(
                                    hovered == tool.id
                                        ? accent.opacity(0.45)
                                        : Color.white.opacity(0.055),
                                    lineWidth: 1
                                )
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onHover { inside in
                        hovered = inside ? tool.id : (hovered == tool.id ? nil : hovered)
                    }
                }
            }

            Text(footnote)
                .font(.system(size: 9.5))
                .foregroundStyle(Color.white.opacity(0.34))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 410)
        .background(Color(white: 0.112))
        .preferredColorScheme(.dark)
    }
}

final class MoreToolsWindowController: NSWindowController {
    init(kind: FileKind, sourceName: String, onSelect: @escaping (String) -> Void) {
        let tools = MoreToolCatalog.tools(for: kind)
        let rows = max(1, Int(ceil(Double(tools.count) / 2.0)))
        let height = CGFloat(156 + rows * 60)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 410, height: height),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "More Tools"
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(calibratedWhite: 0.112, alpha: 1)
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.contentViewController = NSHostingController(
            rootView: MoreToolsView(
                heading: "More Tools",
                sourceName: sourceName,
                tools: tools,
                footnote: "Only tools that apply to this file are shown.",
                onSelect: onSelect
            )
        )
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("not used") }
}


// MARK: - More formats

private enum MoreFormatCatalog {
    static func tools(for targets: [String]) -> [MoreTool] {
        targets.map { target in
            MoreTool(
                id: "convert:\(target)",
                title: FormatCatalog.displayName(target),
                detail: detail(target),
                symbol: symbol(target)
            )
        }
    }

    private static func detail(_ target: String) -> String {
        switch target.lowercased() {
        case "html": return "Web page with text"
        case "rtf": return "Rich text for Word"
        case "rtfd": return "Rich text and attachments"
        case "svg": return "Scalable page image"
        case "bmp": return "Uncompressed bitmap"
        case "tiff": return "Lossless print image"
        case "md": return "Markdown notes"
        case "txt": return "Plain text"
        case "epub": return "Ebook for Books"
        case "jpg": return "Compact photo"
        case "png": return "Lossless image"
        case "docx": return "Word document"
        case "pdf": return "Portable document"
        case "xlsx": return "Excel workbook"
        case "ods": return "OpenDocument sheet"
        case "csv": return "Comma-separated values"
        case "tsv": return "Tab-separated values"
        default: return target.uppercased()
        }
    }

    private static func symbol(_ target: String) -> String {
        switch target.lowercased() {
        case "html": return "chevron.left.forwardslash.chevron.right"
        case "rtf", "rtfd", "docx", "pdf": return "doc.richtext"
        case "epub": return "book"
        case "svg": return "square.on.circle"
        case "bmp", "tiff", "jpg", "png": return "photo"
        case "md", "txt": return "doc.plaintext"
        case "xlsx", "ods", "csv", "tsv": return "tablecells"
        default: return "arrow.right.doc"
        }
    }
}

final class MoreFormatsWindowController: NSWindowController {
    init(targets: [String], sourceName: String, onSelect: @escaping (String) -> Void) {
        let tools = MoreFormatCatalog.tools(for: targets)
        let rows = max(1, Int(ceil(Double(tools.count) / 2.0)))
        let height = CGFloat(156 + rows * 60)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 410, height: height),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "More Formats"
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(calibratedWhite: 0.112, alpha: 1)
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.contentViewController = NSHostingController(
            rootView: MoreToolsView(
                heading: "More Formats",
                sourceName: sourceName,
                tools: tools,
                footnote: "The six most-used formats stay on the dial.",
                onSelect: onSelect
            )
        )
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("not used") }
}
