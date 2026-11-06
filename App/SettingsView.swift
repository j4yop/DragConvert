import SwiftUI
import AppKit
import WheelUI
import CapabilityGraph

enum SettingsTab: String, CaseIterable, Identifiable {
    case general, formats, compatibility, folders, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .formats: return "Formats"
        case .compatibility: return "Compatibility"
        case .folders: return "Folders"
        case .about: return "About"
        }
    }
}

@MainActor
final class SettingsModel: ObservableObject {
    @Published var tab: SettingsTab

    init(tab: SettingsTab = .general) {
        self.tab = tab
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    @AppStorage("wheelStyle") private var wheelStyle = WheelStyle.glass.rawValue
    @AppStorage("wheelConvertShortcut") private var convert = WheelShortcut.shift.rawValue
    @AppStorage("wheelToolsShortcut") private var tools = WheelShortcut.command.rawValue
    @AppStorage("wheelActionsShortcut") private var actions = WheelShortcut.control.rawValue
    @AppStorage("soundEnabled") private var sound = true
    @AppStorage("hapticsEnabled") private var haptics = true
    @AppStorage("revealOnFinish") private var reveal = true
    @AppStorage("showMenuBarIcon") private var showMenuBar = true
    @AppStorage("terminalBundleID") private var terminal = TerminalApps.selectedBundleID
    @AppStorage("floatBehavior") private var floatBehavior = "Create a New Float"

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var folderPath = FolderAccess.shared.currentPath ?? ""
    @State private var folderName = FolderAccess.shared.currentName ?? ""

    // Formats
    @State private var search = ""
    @State private var selectedFormat = "jpg"
    @State private var quality = "high"
    @State private var preserveMetadata = true
    @State private var compression = "custom"

    private let accent = Color(red: 1.0, green: 0.322, blue: 0.0)
    private let panel = Color(white: 0.155)
    private let hairline = Color.white.opacity(0.075)

    private var hasDuplicateShortcut: Bool {
        Set([convert, tools, actions]).count < 3
    }

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.6.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "7"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
                .padding(.top, 10)
                .padding(.bottom, 8)

            ScrollView {
                Group {
                    switch model.tab {
                    case .general:
                        generalTab
                    case .formats:
                        formatsTab
                    case .compatibility:
                        compatibilityTab
                    case .folders:
                        foldersTab
                    case .about:
                        aboutTab
                    }
                }
                .padding(.horizontal, 38)
                .padding(.top, 4)
                .padding(.bottom, 26)
            }
            .scrollIndicators(.visible)
        }
        .frame(width: 478, height: 574)
        .background(Color(white: 0.112))
        .preferredColorScheme(.dark)
        .onAppear {
            refreshFolder()
        }
        .onChange(of: showMenuBar) { value in
            UserDefaults.standard.set(value, forKey: "showMenuBarIcon")
            NotificationCenter.default.post(name: .menuBarVisibilityChanged, object: value)
        }
        .onChange(of: selectedFormat) { _ in
            loadFormatSettings()
        }
        .onChange(of: quality) { value in
            UserDefaults.standard.set(value, forKey: "formatQuality.\(selectedFormat)")
        }
        .onChange(of: preserveMetadata) { value in
            UserDefaults.standard.set(value, forKey: "formatPreserve.\(selectedFormat)")
        }
        .onChange(of: compression) { value in
            UserDefaults.standard.set(value, forKey: "formatCompression.\(selectedFormat)")
        }
    }

    // MARK: - Tabs

    private var tabBar: some View {
        HStack(spacing: 3) {
            ForEach(SettingsTab.allCases) { tab in
                Button {
                    model.tab = tab
                } label: {
                    Text(tab.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(tab == model.tab ? Color.white : Color.white.opacity(0.86))
                        .padding(.horizontal, 11)
                        .frame(height: 27)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(tab == model.tab ? Color(white: 0.29) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 38)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - General

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 11) {
            groupBox {
                HStack(spacing: 12) {
                    Text("Style")
                        .font(.system(size: 13))
                    Spacer(minLength: 8)
                    styleControl
                }
                .frame(height: 32)
            }

            Text("General")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.82))

            groupBox {
                checkRow("Launch at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { value in
                        launchAtLogin = value
                        LaunchAtLogin.set(value)
                    }
                ))
                checkRow("Show DragConvert in menu bar", isOn: $showMenuBar)
                divider
                checkRow("Sound feedback", isOn: $sound)
                checkRow("Haptic feedback", isOn: $haptics)
                checkRow("Show Desktop results in Finder", isOn: $reveal)
                divider

                Text("Drag Modifiers")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.84))
                    .padding(.top, 6)
                    .padding(.bottom, 4)

                shortcutRow("Conversion wheel", selection: $convert)
                shortcutRow("Tools wheel", selection: $tools)
                shortcutRow("Actions wheel", selection: $actions)

                Text("Tap the chosen modifier combination while dragging files.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.white.opacity(0.42))
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                divider
                menuRow(
                    "Float Behaviour",
                    selection: $floatBehavior,
                    options: ["Create a New Float", "Add to Existing Float"],
                    width: 215
                )
                divider
                terminalRow
            }

            HStack {
                Spacer()
                Button("Quit DragConvert") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(accent)
                .padding(.trailing, 4)
            }
            .padding(.top, 2)
        }
    }

    private var styleControl: some View {
        HStack(spacing: 0) {
            ForEach(WheelStyle.allCases) { style in
                Button {
                    wheelStyle = style.rawValue
                } label: {
                    Text(style.title)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(wheelStyle == style.rawValue ? Color.white : Color.white.opacity(0.86))
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                                .fill(wheelStyle == style.rawValue ? accent : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .frame(width: 220)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(white: 0.27))
        )
    }

    private func checkRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isOn.wrappedValue ? accent : Color.white.opacity(0.16))
                        .frame(width: 18, height: 18)
                    if isOn.wrappedValue {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.92))
                Spacer(minLength: 8)
            }
            .frame(height: 29)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func shortcutRow(_ title: String, selection: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.92))
            Spacer(minLength: 8)
            PopupControl(
                title: WheelShortcut(rawValue: selection.wrappedValue)?.menuTitle ?? selection.wrappedValue,
                width: 215,
                options: WheelShortcut.allCases.map {
                    PopupOption(id: $0.rawValue, title: $0.menuTitle)
                },
                onSelect: { selection.wrappedValue = $0 }
            )
        }
        .frame(height: 30)
    }

    private func menuRow(
        _ title: String,
        selection: Binding<String>,
        options: [String],
        width: CGFloat
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.92))
            Spacer(minLength: 8)
            PopupControl(
                title: selection.wrappedValue,
                width: width,
                options: options.map { PopupOption(id: $0, title: $0) },
                onSelect: { selection.wrappedValue = $0 }
            )
        }
        .frame(height: 30)
    }

    private var terminalRow: some View {
        HStack(spacing: 10) {
            Text("Terminal app")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.92))
            Spacer(minLength: 8)
            Text(currentTerminalName)
                .font(.system(size: 12.5))
                .foregroundStyle(Color.white.opacity(0.62))
            PopupControl(
                title: "Choose…",
                width: 108,
                options: TerminalApps.installed.map {
                    PopupOption(id: $0.id, title: $0.name)
                },
                onSelect: { terminal = $0 }
            )
        }
        .frame(height: 30)
    }

    private var currentTerminalName: String {
        TerminalApps.installed.first(where: { $0.id == terminal })?.name ?? "Terminal"
    }

    // MARK: - Formats

    private static let formats: [FormatInfo] = [
        FormatInfo(id: "jpg", name: "JPG", description: "JPEG is a lossy image format. Best for photos and sharing.", lossy: true, settings: true),
        FormatInfo(id: "png", name: "PNG", description: "PNG is lossless and supports transparency. Best for graphics and screenshots.", lossy: false, settings: true),
        FormatInfo(id: "heic", name: "HEIC", description: "HEIC is an efficient modern image format for Apple devices.", lossy: true, settings: true),
        FormatInfo(id: "tiff", name: "TIFF", description: "TIFF is a lossless, high-quality format for archiving and print.", lossy: false, settings: true),
        FormatInfo(id: "bmp", name: "BMP", description: "BMP is an uncompressed bitmap for maximum compatibility.", lossy: false, settings: true),
        FormatInfo(id: "avif", name: "AVIF", description: "AVIF is a modern image format with excellent compression.", lossy: true, settings: true),
        FormatInfo(id: "webp", name: "WEBP", description: "WebP is a compact image format for the web.", lossy: true, settings: true),
        FormatInfo(id: "pdf", name: "PDF", description: "PDF keeps pages, vectors and text together.", lossy: false, settings: false),
        FormatInfo(id: "txt", name: "TXT", description: "Plain text extracted from a PDF.", lossy: false, settings: false),
        FormatInfo(id: "md", name: "MD", description: "Markdown with structure extracted from a PDF.", lossy: false, settings: false)
    ]

    private var filteredFormats: [FormatInfo] {
        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return Self.formats }
        return Self.formats.filter {
            $0.name.lowercased().contains(needle) || $0.description.lowercased().contains(needle)
        }
    }

    private var selectedFormatInfo: FormatInfo {
        Self.formats.first(where: { $0.id == selectedFormat }) ?? Self.formats[0]
    }

    private var formatsTab: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.45))
                    TextField("Search", text: $search)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 8)
                .frame(height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(white: 0.085))
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(filteredFormats) { format in
                            Button {
                                selectedFormat = format.id
                            } label: {
                                Text(format.name)
                                    .font(.system(size: 11.5, weight: selectedFormat == format.id ? .semibold : .regular))
                                    .foregroundStyle(Color.white.opacity(selectedFormat == format.id ? 0.96 : 0.80))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 7)
                                    .frame(height: 24)
                                    .background(
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .fill(selectedFormat == format.id ? Color.white.opacity(0.13) : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            .frame(width: 148)

            Rectangle()
                .fill(hairline)
                .frame(width: 1)
                .padding(.horizontal, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(selectedFormatInfo.name)
                        .font(.system(size: 18, weight: .semibold))
                    Text(selectedFormatInfo.description)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.50))
                        .fixedSize(horizontal: false, vertical: true)

                    if selectedFormatInfo.settings {
                        Text("Conversion Settings")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.84))
                            .padding(.top, 6)

                        groupBox {
                            if selectedFormatInfo.lossy {
                                HStack {
                                    Text("Quality")
                                        .font(.system(size: 13))
                                    Spacer()
                                    PopupControl(
                                        title: QualityOption.title(for: quality),
                                        width: 130,
                                        options: QualityOption.all.map {
                                            PopupOption(id: $0.id, title: $0.title)
                                        },
                                        onSelect: { quality = $0 }
                                    )
                                }
                                .frame(height: 32)
                                divider
                            }
                            checkRow("Preserve metadata", isOn: $preserveMetadata)
                            divider
                            HStack {
                                Spacer()
                                Button("Restore Defaults") {
                                    quality = "high"
                                    preserveMetadata = true
                                    compression = "custom"
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(accent)
                            }
                            .frame(height: 28)
                        }

                        if selectedFormatInfo.lossy {
                            Text("Image Compression")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.84))
                                .padding(.top, 4)

                            HStack(spacing: 0) {
                                ForEach(CompressionOption.all) { option in
                                    Button {
                                        compression = option.id
                                    } label: {
                                        Text(option.title)
                                            .font(.system(size: 9.5, weight: .medium))
                                            .foregroundStyle(compression == option.id ? Color.white : Color.white.opacity(0.74))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.75)
                                            .frame(width: 72, height: 24)
                                            .background(
                                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                                    .fill(compression == option.id ? accent : Color.clear)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(3)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color(white: 0.27))
                            )

                            Text("Custom keeps the encoder defaults. The presets trade quality for a smaller file.")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.white.opacity(0.42))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        Text("This output format has no adjustable conversion defaults.")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(0.50))
                            .padding(.top, 10)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.visible)
        }
        .frame(height: 470, alignment: .top)
    }

    private func loadFormatSettings() {
        let defaults = UserDefaults.standard
        quality = defaults.string(forKey: "formatQuality.\(selectedFormat)") ?? "high"
        preserveMetadata = defaults.object(forKey: "formatPreserve.\(selectedFormat)") as? Bool ?? true
        compression = defaults.string(forKey: "formatCompression.\(selectedFormat)") ?? "custom"
    }

    // MARK: - Compatibility

    private static let columns = ["JPG", "PNG", "HEIC", "TIFF", "BMP", "AVIF", "PDF"]
    private static let imageRows = ["JPG", "PNG", "HEIC", "TIFF", "BMP", "AVIF", "WEBP"]

    private var compatibilityTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Input × output")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.82))

                compatibilitySection(
                    "Images",
                    rows: Self.imageRows,
                    checked: { row in
                        Self.columns.map { column in
                            column == "PDF" || Self.columns.dropLast().contains(column)
                        }
                    }
                )

                compatibilitySection(
                    "PDF",
                    rows: ["PDF"],
                    checked: { _ in
                        ["JPG", "PNG", "TIFF", "BMP"].map { Self.columns.contains($0) }
                    }
                )

                Text("Only conversions with a working engine are checked. Nothing is advertised until it can run on this Mac.")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.40))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .scrollIndicators(.visible)
        .frame(height: 470, alignment: .top)
    }

    private func compatibilitySection(
        _ title: String,
        rows: [String],
        checked: @escaping (String) -> [Bool]
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.84))
                .padding(.bottom, 2)

            HStack(spacing: 0) {
                Text("")
                    .frame(width: 58, alignment: .leading)
                ForEach(Self.columns, id: \.self) { column in
                    Text(column)
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.48))
                        .frame(width: 40)
                }
            }
            .frame(height: 18)

            ForEach(rows, id: \.self) { row in
                HStack(spacing: 0) {
                    Text(row)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.88))
                        .frame(width: 58, alignment: .leading)
                    let marks = checked(row)
                    ForEach(Array(Self.columns.enumerated()), id: \.offset) { index, _ in
                        Group {
                            if index < marks.count, marks[index] {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.82))
                            } else {
                                Color.clear
                            }
                        }
                        .frame(width: 40, height: 23)
                    }
                }
            }
        }
    }

    // MARK: - Folders

    private var foldersTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Folder Access")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.84))

            Text("DragConvert saves results beside the originals. macOS asks you to allow access once. Each folder you add is remembered with a security-scoped bookmark.")
                .font(.system(size: 10.5))
                .foregroundStyle(Color.white.opacity(0.48))
                .fixedSize(horizontal: false, vertical: true)

            groupBox {
                if folderPath.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "folder.badge.questionmark")
                            .foregroundStyle(Color.white.opacity(0.55))
                        Text("No folder access yet")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.82))
                        Spacer()
                    }
                    .frame(height: 32)
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(Color(red: 0.28, green: 0.56, blue: 0.94))
                        Text(folderName)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.92))
                        Spacer()
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.72))
                    }
                    .frame(height: 30)
                    Text(folderPath)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.40))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.leading, 28)
                        .padding(.bottom, 6)
                }
                divider
                HStack {
                    Button("Add Folder…") {
                        if FolderAccess.shared.prompt() {
                            refreshFolder()
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(accent)
                    Spacer()
                }
                .frame(height: 30)
            }

            Spacer(minLength: 0)
        }
        .frame(height: 470, alignment: .top)
    }

    private func refreshFolder() {
        folderPath = FolderAccess.shared.currentPath ?? ""
        folderName = FolderAccess.shared.currentName ?? ""
    }

    // MARK: - About

    private var aboutTab: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 76, height: 76)
                .padding(.top, 14)

            Text("DragConvert")
                .font(.system(size: 20, weight: .semibold))
            Text(version)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.55))
            Text("Free and open source · GPL-3.0-only")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(accent)

            Text("A local-first file wheel for macOS. Drop files, choose a format or tool, and the result is saved beside the original.")
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.50))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .padding(.top, 4)

            HStack(spacing: 12) {
                linkButton("GitHub", "https://github.com/j4yop/DragConvert")
                linkButton("Releases", "https://github.com/j4yop/DragConvert/releases")
                linkButton("License", "https://github.com/j4yop/DragConvert/blob/main/LICENSE")
            }
            .padding(.top, 8)

            Button("Show Welcome Tour") {
                UserDefaults.standard.set(false, forKey: "hasSeenWelcome")
                NotificationCenter.default.post(name: .showOnboarding, object: nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(accent)
            .padding(.top, 4)

            Spacer(minLength: 0)

            Text("DragConvert is not affiliated with Tangerine or Leap Studio.")
                .font(.system(size: 9.5))
                .foregroundStyle(Color.white.opacity(0.30))
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 470, alignment: .top)
    }

    private func linkButton(_ title: String, _ address: String) -> some View {
        Button(title) {
            guard let url = URL(string: address) else { return }
            NSWorkspace.shared.open(url)
        }
        .buttonStyle(.plain)
        .font(.system(size: 11.5, weight: .medium))
        .foregroundStyle(accent)
    }

    // MARK: - Shared components

    private func groupBox<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.white.opacity(0.055), lineWidth: 1)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(hairline)
            .frame(height: 1)
            .padding(.vertical, 4)
    }
}

// MARK: - Format data

private struct FormatInfo: Identifiable {
    let id: String
    let name: String
    let description: String
    let lossy: Bool
    let settings: Bool
}

private struct QualityOption: Identifiable {
    let id: String
    let title: String

    static let all = [
        QualityOption(id: "best", title: "Best"),
        QualityOption(id: "high", title: "High"),
        QualityOption(id: "medium", title: "Medium"),
        QualityOption(id: "low", title: "Low")
    ]

    static func title(for id: String) -> String {
        all.first(where: { $0.id == id })?.title ?? "High"
    }
}

private struct CompressionOption: Identifiable {
    let id: String
    let title: String

    static let all = [
        CompressionOption(id: "custom", title: "Custom"),
        CompressionOption(id: "smallestQuality", title: "Smallest Quality"),
        CompressionOption(id: "smallestFile", title: "Smallest File")
    ]
}

// MARK: - Popup control

private struct PopupOption: Identifiable {
    let id: String
    let title: String
}

private final class PopupTarget: NSObject {
    var actions: [String: () -> Void] = [:]

    @objc func select(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        actions[key]?()
    }
}

private struct PopupControl: View {
    let title: String
    let width: CGFloat
    let options: [PopupOption]
    let onSelect: (String) -> Void

    @State private var target = PopupTarget()

    private let accent = Color(red: 1.0, green: 0.322, blue: 0.0)

    var body: some View {
        Button {
            let menu = NSMenu()
            menu.autoenablesItems = false
            target.actions = [:]
            for option in options {
                let item = NSMenuItem(
                    title: option.title,
                    action: #selector(PopupTarget.select(_:)),
                    keyEquivalent: ""
                )
                item.target = target
                item.representedObject = option.id
                target.actions[option.id] = { onSelect(option.id) }
                menu.addItem(item)
            }
            menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        } label: {
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(accent)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(accent)
            }
            .padding(.horizontal, 9)
            .frame(width: width, height: 26)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(white: 0.205))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Window

final class SettingsWindowController: NSWindowController {
    private let model: SettingsModel

    init(initialTab: SettingsTab = .general) {
        var tab = initialTab
        if let index = CommandLine.arguments.firstIndex(of: "--settings-demo"),
           index + 1 < CommandLine.arguments.count,
           let requested = SettingsTab(rawValue: CommandLine.arguments[index + 1]) {
            tab = requested
        }
        model = SettingsModel(tab: tab)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 478, height: 574),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DragConvert Settings"
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(calibratedWhite: 0.185, alpha: 1)
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.contentViewController = NSHostingController(rootView: SettingsView(model: model))
        if let titlebar = window.standardWindowButton(.closeButton)?.superview {
            let label = NSTextField(labelWithString: "DragConvert Settings")
            label.font = .systemFont(ofSize: 13, weight: .semibold)
            label.textColor = NSColor(calibratedWhite: 0.82, alpha: 1)
            label.translatesAutoresizingMaskIntoConstraints = false
            titlebar.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: titlebar.leadingAnchor, constant: 80),
                label.centerYAnchor.constraint(equalTo: titlebar.centerYAnchor)
            ])
        }
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func select(tab: SettingsTab) {
        model.tab = tab
    }
}
