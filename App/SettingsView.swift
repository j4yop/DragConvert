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

    init(model: SettingsModel) {
        self.model = model
        var initial = "jpg"
        if let index = CommandLine.arguments.firstIndex(of: "--format-demo"),
           index + 1 < CommandLine.arguments.count {
            initial = CommandLine.arguments[index + 1]
        }
        _selectedFormat = State(initialValue: initial)
    }

    @AppStorage("wheelStyle") private var wheelStyle = WheelStyle.glass.rawValue
    @AppStorage("wheelConvertShortcut") private var convert = WheelShortcut.shift.rawValue
    @AppStorage("wheelToolsShortcut") private var tools = WheelShortcut.optionCommand.rawValue
    @AppStorage("wheelActionsShortcut") private var actions = WheelShortcut.controlCommand.rawValue
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
    @State private var profile = FormatProfileValues()

    private let accent = Color(red: 1.0, green: 0.322, blue: 0.0)
    private let panel = Color(white: 0.155)
    private let hairline = Color.white.opacity(0.075)

    private var hasDuplicateShortcut: Bool {
        Set([convert, tools, actions]).count < 3
    }

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.7.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "8"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
                .padding(.top, 10)
                .padding(.bottom, 4)

            Group {
                switch model.tab {
                case .general:
                    generalTab
                case .formats:
                    formatsTab
                        .padding(.horizontal, 30)
                        .padding(.top, 2)
                        .padding(.bottom, 18)
                case .compatibility:
                    compatibilityTab
                        .padding(.horizontal, 30)
                        .padding(.top, 4)
                        .padding(.bottom, 18)
                case .folders:
                    ScrollView {
                        foldersTab
                            .padding(.horizontal, 30)
                            .padding(.top, 4)
                            .padding(.bottom, 26)
                    }
                    .scrollIndicators(.visible)
                case .about:
                    ScrollView {
                        aboutTab
                            .padding(.horizontal, 30)
                            .padding(.top, 4)
                            .padding(.bottom, 26)
                    }
                    .scrollIndicators(.visible)
                }
            }
        }
        .frame(width: 478, height: 574)
        .background(Color(white: 0.112))
        .preferredColorScheme(.dark)
        .onAppear {
            refreshFolder()
            loadProfile(for: selectedFormat)
        }
        .onChange(of: showMenuBar) { value in
            UserDefaults.standard.set(value, forKey: "showMenuBarIcon")
            NotificationCenter.default.post(name: .menuBarVisibilityChanged, object: value)
        }
        .onChange(of: selectedFormat) { value in
            loadProfile(for: value)
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
        .padding(.leading, 30)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - General

    private var generalTab: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 9) {
                    Text("Appearance")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.82))
            groupBox {
                HStack(spacing: 12) {
                    Text("Style")
                        .font(.system(size: 13))
                    styleControl
                        .frame(width: 112)
                    Spacer(minLength: 8)
                }
                .frame(height: 25)
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
                    width: 235
                )
                divider
                terminalRow
            }

                }
                .padding(.horizontal, 30)
                .padding(.top, 4)
                .padding(.bottom, 10)
            }
            .scrollIndicators(.visible)

            HStack {
                Spacer()
                Button("Quit DragConvert") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(accent)
                .padding(.trailing, 30)
            }
            .frame(height: 30)
            .padding(.bottom, 8)
            .background(Color(white: 0.112))
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
        .frame(width: 112)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(white: 0.27))
        )
    }

    private func checkRow(_ title: String, isOn: Binding<Bool>, fontSize: CGFloat = 13) -> some View {
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
                    .font(.system(size: fontSize))
                    .foregroundStyle(Color.white.opacity(0.92))
                Spacer(minLength: 8)
            }
            .frame(height: 26)
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
                width: 235,
                options: WheelShortcut.allCases.map {
                    PopupOption(id: $0.rawValue, title: $0.menuTitle)
                },
                fontSize: 13,
                background: Color(red: 0.24, green: 0.13, blue: 0.09),
                onSelect: { selection.wrappedValue = $0 }
            )
        }
        .frame(height: 28)
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
                fontSize: 13,
                background: Color(red: 0.24, green: 0.13, blue: 0.09),
                onSelect: { selection.wrappedValue = $0 }
            )
        }
        .frame(height: 28)
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
                fontSize: 13,
                background: Color(red: 0.24, green: 0.13, blue: 0.09),
                onSelect: { terminal = $0 }
            )
        }
        .frame(height: 28)
    }

    private var currentTerminalName: String {
        TerminalApps.installed.first(where: { $0.id == terminal })?.name ?? "Terminal"
    }

    // MARK: - Formats

    private var filteredCategories: [(FormatCategory, [FormatSpec])] {
        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return FormatCategory.allCases.compactMap { category in
            let items = FormatCatalog.inCategory(category).filter { format in
                needle.isEmpty
                    || format.name.lowercased().contains(needle)
                    || format.description.lowercased().contains(needle)
                    || format.extensions.contains { $0.contains(needle) }
            }
            return items.isEmpty ? nil : (category, items)
        }
    }

    private var selectedFormatInfo: FormatSpec {
        FormatCatalog.format(selectedFormat) ?? FormatCatalog.images[0]
    }

    private var formatsTab: some View {
        HStack(alignment: .top, spacing: 10) {
            formatsSidebar
            Rectangle()
                .fill(hairline)
                .frame(width: 1)
            formatDetail
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var formatsSidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.42))
                TextField("Search", text: $search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5))
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(white: 0.075))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredCategories, id: \.0) { category, items in
                            Text(category.title)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.36))
                                .padding(.top, 9)
                                .padding(.bottom, 3)
                            ForEach(items) { format in
                                Button {
                                    selectedFormat = format.id
                                } label: {
                                    Text(format.name)
                                        .font(.system(size: 12.5, weight: selectedFormat == format.id ? .semibold : .regular))
                                        .foregroundStyle(Color.white.opacity(selectedFormat == format.id ? 0.96 : 0.78))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 8)
                                        .frame(height: 26)
                                        .background(
                                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                                .fill(selectedFormat == format.id ? accent.opacity(0.24) : Color.clear)
                                        )
                                }
                                .buttonStyle(.plain)
                                .id(format.id)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    DispatchQueue.main.async {
                        proxy.scrollTo(selectedFormat, anchor: .center)
                    }
                }
                .onChange(of: selectedFormat) { value in
                    withAnimation(.easeOut(duration: 0.16)) {
                        proxy.scrollTo(value, anchor: .center)
                    }
                }
                .onChange(of: search) { _ in
                    DispatchQueue.main.async {
                        proxy.scrollTo(selectedFormat, anchor: .center)
                    }
                }
            }
        }
        .frame(width: 114)
    }

    private var formatDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(selectedFormatInfo.name) Settings")
                    .font(.system(size: 16.5, weight: .bold))
                Text(selectedFormatInfo.description)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.white.opacity(0.48))
                    .fixedSize(horizontal: false, vertical: true)

                if selectedFormatInfo.settings.any {
                    Text("Conversion Settings")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.86))
                        .padding(.top, 6)
                    conversionSettings
                }

                if selectedFormatInfo.settings.videoCompression {
                    Text("Compression Settings")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.86))
                        .padding(.top, 4)
                    videoCompressionSettings
                }

                if selectedFormatInfo.settings.imageCompression {
                    Text("Image Compression")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.86))
                        .padding(.top, 4)
                    imageCompressionSettings
                }

                if !selectedFormatInfo.settings.any {
                    Text("This output format has no adjustable conversion defaults.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.white.opacity(0.46))
                        .padding(.top, 6)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.visible)
    }

    private var conversionSettings: some View {
        groupBox {
            if selectedFormatInfo.settings.quality {
                settingRow("Quality") {
                    PopupControl(
                        title: qualityTitle(profile.quality),
                        width: 120,
                        options: qualityOptions,
                        onSelect: { profile.quality = $0; saveProfile() }
                    )
                }
            }
            if selectedFormatInfo.settings.metadata {
                checkRow("Preserve metadata", isOn: bind(\.preserveMetadata))
            }
            if selectedFormatInfo.settings.pdfLayout {
                settingRow("PDF layout") {
                    PopupControl(
                        title: pdfLayoutTitle(profile.pdfLayout),
                        width: 180,
                        options: pdfLayoutOptions,
                        onSelect: { profile.pdfLayout = $0; saveProfile() }
                    )
                }
                if selectedFormatInfo.category == .documents {
                    Text(pdfLayoutCaption)
                        .font(.system(size: 9.5))
                        .foregroundStyle(Color.white.opacity(0.42))
                        .fixedSize(horizontal: false, vertical: true)
                    if selectedFormatInfo.id == "pages" {
                        Text("Creates a native Pages document directly on your Mac.")
                            .font(.system(size: 9.5))
                            .foregroundStyle(Color.white.opacity(0.42))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if selectedFormatInfo.id == "epub" {
                        Text("Creates a reflowable EPUB with chapters and inline images.")
                            .font(.system(size: 9.5))
                            .foregroundStyle(Color.white.opacity(0.42))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if selectedFormatInfo.settings.audioBitrate {
                settingRow("Audio bitrate") {
                    PopupControl(
                        title: profile.audioBitrate,
                        width: 130,
                        options: bitrateOptions,
                        onSelect: { profile.audioBitrate = $0; saveProfile() }
                    )
                }
            }
            if selectedFormatInfo.settings.audioDepth {
                settingRow("Audio bit depth") {
                    PopupControl(
                        title: audioDepthTitle(profile.audioDepth),
                        width: 170,
                        options: audioDepthOptions,
                        onSelect: { profile.audioDepth = $0; saveProfile() }
                    )
                }
            }
            if selectedFormatInfo.settings.videoQuality {
                settingRow("Quality") {
                    PopupControl(
                        title: qualityTitle(profile.videoQuality),
                        width: 130,
                        options: qualityOptions,
                        onSelect: { profile.videoQuality = $0; saveProfile() }
                    )
                }
            }
            if selectedFormatInfo.settings.videoHeight {
                settingRow("Maximum video height") {
                    PopupControl(
                        title: videoHeightTitle(profile.videoMaxHeight),
                        width: 120,
                        options: videoHeightOptions,
                        onSelect: { profile.videoMaxHeight = $0; saveProfile() }
                    )
                }
            }
            if selectedFormatInfo.settings.archiveCompression {
                settingRow("Compression") {
                    PopupControl(
                        title: archiveTitle(profile.archiveCompression),
                        width: 130,
                        options: archiveOptions,
                        onSelect: { profile.archiveCompression = $0; saveProfile() }
                    )
                }
            }
            if selectedFormatInfo.settings.gifOptions {
                settingRow("Frame rate") {
                    PopupControl(
                        title: gifFrameTitle(profile.gifFrameRate),
                        width: 130,
                        options: gifFrameOptions,
                        onSelect: { profile.gifFrameRate = $0; saveProfile() }
                    )
                }
                settingRow("Maximum width") {
                    PopupControl(
                        title: gifWidthTitle(profile.gifMaxWidth),
                        width: 160,
                        options: gifWidthOptions,
                        onSelect: { profile.gifMaxWidth = $0; saveProfile() }
                    )
                }
            }
            if selectedFormatInfo.settings.epubLayout {
                settingRow("EPUB layout") {
                    PopupControl(
                        title: profile.epubLayout == "fixed" ? "Fixed layout" : "Adjustable text",
                        width: 160,
                        options: [
                            PopupOption(id: "adjustable", title: "Adjustable text"),
                            PopupOption(id: "fixed", title: "Fixed layout")
                        ],
                        onSelect: { profile.epubLayout = $0; saveProfile() }
                    )
                }
            }
            divider
            restoreRow("Restore Defaults") {
                resetConversionDefaults()
            }
        }
    }

    private var imageCompressionSettings: some View {
        groupBox {
            settingRow("Compression") {
                compressionSegmented(
                    selection: bind(\.imageCompression),
                    options: [
                        PopupOption(id: "balanced", title: "Balanced"),
                        PopupOption(id: "strong", title: "Strong")
                    ]
                )
            }
            settingRow("Image size") {
                PopupControl(
                    title: imageSizeTitle(profile.imageSize),
                    width: 180,
                    options: imageSizeOptions,
                    onSelect: { profile.imageSize = $0; saveProfile() }
                )
            }
            divider
            restoreRow("Restore Compression Defaults") {
                profile.imageCompression = "balanced"
                profile.imageSize = "original"
                saveProfile()
            }
        }
    }

    private var videoCompressionSettings: some View {
        groupBox {
            HStack(spacing: 10) {
                Text("Compression")
                    .font(.system(size: 11.5))
                Spacer(minLength: 8)
                compressionSegmented(
                    selection: bind(\.videoCompression),
                    options: [
                        PopupOption(id: "balanced", title: "Balanced"),
                        PopupOption(id: "strong", title: "Strong")
                    ]
                )
            }
            .frame(minHeight: 30)
            Text(profile.videoCompression == "strong"
                 ? "Much smaller files with more visible quality loss."
                 : "Better visual quality with moderate file-size savings.")
                .font(.system(size: 9.5))
                .foregroundStyle(Color.white.opacity(0.42))
                .fixedSize(horizontal: false, vertical: true)
            divider
            restoreRow("Restore Compression Defaults") {
                profile.videoCompression = "balanced"
                saveProfile()
            }
        }
    }

    private func settingRow<Control: View>(_ title: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11.5))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(Color.white.opacity(0.92))
            Spacer(minLength: 8)
            control()
        }
        .frame(minHeight: 30)
    }

    private func restoreRow(_ title: String, action: @escaping () -> Void) -> some View {
        HStack {
            Spacer()
            Button(action: action) {
                Text(title)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 9)
                    .frame(height: 23)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(accent.opacity(0.13))
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(height: 28)
    }

    private func compressionSegmented(selection: Binding<String>, options: [PopupOption]) -> some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                Button {
                    selection.wrappedValue = option.id
                } label: {
                    Text(option.title)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(selection.wrappedValue == option.id ? Color.white : Color.white.opacity(0.68))
                        .frame(width: 64, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                                .fill(selection.wrappedValue == option.id ? accent : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2.5)
        .background(
            RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                .fill(Color(white: 0.26))
        )
    }

    private let qualityOptions = [
        PopupOption(id: "smallerFile", title: "Smaller File"),
        PopupOption(id: "balanced", title: "Balanced"),
        PopupOption(id: "higherQuality", title: "Higher Quality")
    ]
    private let pdfLayoutOptions = [
        PopupOption(id: "editable", title: "Editable paragraphs"),
        PopupOption(id: "preservePages", title: "Preserve original pages")
    ]
    private let bitrateOptions = [
        PopupOption(id: "128 kbps", title: "128 kbps"),
        PopupOption(id: "192 kbps", title: "192 kbps"),
        PopupOption(id: "256 kbps", title: "256 kbps"),
        PopupOption(id: "320 kbps", title: "320 kbps")
    ]
    private let audioDepthOptions = [
        PopupOption(id: "matchSource", title: "Match source"),
        PopupOption(id: "16", title: "16-bit integer"),
        PopupOption(id: "24", title: "24-bit integer"),
        PopupOption(id: "32", title: "32-bit integer"),
        PopupOption(id: "float32", title: "32-bit float")
    ]
    private let videoHeightOptions = [
        PopupOption(id: "original", title: "Original"),
        PopupOption(id: "2160", title: "2160p"),
        PopupOption(id: "1080", title: "1080p"),
        PopupOption(id: "720", title: "720p"),
        PopupOption(id: "480", title: "480p")
    ]
    private let archiveOptions = [
        PopupOption(id: "fast", title: "Faster"),
        PopupOption(id: "balanced", title: "Balanced"),
        PopupOption(id: "smallest", title: "Smallest File")
    ]
    private let imageSizeOptions = [
        PopupOption(id: "original", title: "Keep original dimensions"),
        PopupOption(id: "4096", title: "Long edge 4096 px"),
        PopupOption(id: "2048", title: "Long edge 2048 px"),
        PopupOption(id: "1024", title: "Long edge 1024 px"),
        PopupOption(id: "50", title: "50%"),
        PopupOption(id: "25", title: "25%")
    ]
    private let gifFrameOptions = [
        PopupOption(id: "original", title: "Match source"),
        PopupOption(id: "30", title: "30 fps"),
        PopupOption(id: "15", title: "15 fps")
    ]
    private let gifWidthOptions = [
        PopupOption(id: "original", title: "Keep original width"),
        PopupOption(id: "1080", title: "1080 px"),
        PopupOption(id: "720", title: "720 px"),
        PopupOption(id: "480", title: "480 px")
    ]

    private func qualityTitle(_ id: String) -> String {
        qualityOptions.first(where: { $0.id == id })?.title ?? "Balanced"
    }
    private func pdfLayoutTitle(_ id: String) -> String {
        pdfLayoutOptions.first(where: { $0.id == id })?.title ?? "Editable paragraphs"
    }
    private func audioDepthTitle(_ id: String) -> String {
        audioDepthOptions.first(where: { $0.id == id })?.title ?? "Match source"
    }
    private func videoHeightTitle(_ id: String) -> String {
        videoHeightOptions.first(where: { $0.id == id })?.title ?? "Original"
    }
    private func archiveTitle(_ id: String) -> String {
        archiveOptions.first(where: { $0.id == id })?.title ?? "Balanced"
    }
    private func gifFrameTitle(_ id: String) -> String {
        gifFrameOptions.first(where: { $0.id == id })?.title ?? "Match source"
    }
    private func gifWidthTitle(_ id: String) -> String {
        gifWidthOptions.first(where: { $0.id == id })?.title ?? "Keep original width"
    }

    private func imageSizeTitle(_ id: String) -> String {
        imageSizeOptions.first(where: { $0.id == id })?.title ?? "Keep original dimensions"
    }

    private var pdfLayoutCaption: String {
        if profile.pdfLayout == "preservePages" {
            return "Keep every page as a sharp image, including tables, equations, and scanned content. Text cannot be edited."
        }
        return "Create normal paragraphs, headings, and tables that reflow when edited. Recognize scanned text with OCR. Keep illustrations as inline images."
    }

    private func loadProfile(for id: String) {
        let d = UserDefaults.standard
        let p = "conversionProfile.\(id)."
        profile.quality = d.string(forKey: p + "quality") ?? "balanced"
        profile.preserveMetadata = d.object(forKey: p + "preserveMetadata") as? Bool ?? true
        profile.imageCompression = d.string(forKey: p + "imageCompressionStrength") ?? "balanced"
        profile.imageSize = d.string(forKey: p + "imageSize") ?? "original"
        profile.pdfLayout = d.string(forKey: p + "pdfOfficeLayout") ?? "editable"
        profile.audioBitrate = d.string(forKey: p + "audioBitrate") ?? "256 kbps"
        profile.audioDepth = d.string(forKey: p + "audioSampleDepth") ?? "matchSource"
        profile.videoQuality = d.string(forKey: p + "videoQuality") ?? "balanced"
        profile.videoMaxHeight = d.string(forKey: p + "videoMaxHeight") ?? "original"
        profile.videoCompression = d.string(forKey: p + "videoCompressionStrength") ?? "balanced"
        profile.archiveCompression = d.string(forKey: p + "compression") ?? "balanced"
        profile.gifFrameRate = d.string(forKey: p + "gifFrameRate") ?? "original"
        profile.gifMaxWidth = d.string(forKey: p + "gifMaxWidth") ?? "original"
        profile.epubLayout = d.string(forKey: p + "epubLayout") ?? "editable"
    }

    private func saveProfile() {
        let d = UserDefaults.standard
        let p = "conversionProfile.\(selectedFormat)."
        d.set(profile.quality, forKey: p + "quality")
        d.set(profile.preserveMetadata, forKey: p + "preserveMetadata")
        d.set(profile.imageCompression, forKey: p + "imageCompressionStrength")
        d.set(profile.imageSize, forKey: p + "imageSize")
        d.set(profile.pdfLayout, forKey: p + "pdfOfficeLayout")
        d.set(profile.audioBitrate, forKey: p + "audioBitrate")
        d.set(profile.audioDepth, forKey: p + "audioSampleDepth")
        d.set(profile.videoQuality, forKey: p + "videoQuality")
        d.set(profile.videoMaxHeight, forKey: p + "videoMaxHeight")
        d.set(profile.videoCompression, forKey: p + "videoCompressionStrength")
        d.set(profile.archiveCompression, forKey: p + "compression")
        d.set(profile.gifFrameRate, forKey: p + "gifFrameRate")
        d.set(profile.gifMaxWidth, forKey: p + "gifMaxWidth")
        d.set(profile.epubLayout, forKey: p + "epubLayout")
    }

    private func bind<T>(_ keyPath: WritableKeyPath<FormatProfileValues, T>) -> Binding<T> {
        Binding(
            get: { profile[keyPath: keyPath] },
            set: {
                profile[keyPath: keyPath] = $0
                saveProfile()
            }
        )
    }

    private func resetConversionDefaults() {
        profile.quality = "balanced"
        profile.preserveMetadata = true
        profile.pdfLayout = "editable"
        profile.audioBitrate = "256 kbps"
        profile.audioDepth = "matchSource"
        profile.videoQuality = "balanced"
        profile.videoMaxHeight = "original"
        profile.archiveCompression = "balanced"
        profile.gifFrameRate = "original"
        profile.gifMaxWidth = "original"
        profile.epubLayout = "editable"
        saveProfile()
    }

    // MARK: - Compatibility

    private var compatibilityTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 7) {
                    Image(systemName: "tablecells")
                        .font(.system(size: 12, weight: .medium))
                    Text("Format Compatibility")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Color.white.opacity(0.82))

                ForEach(FormatCategory.allCases) { category in
                    compatibilityCard(category)
                }

                Text("A dash means this build cannot write that pair. Checkmarks follow the format’s published output set.")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Color.white.opacity(0.34))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            .frame(width: 418, alignment: .leading)
        }
        .scrollIndicators(.visible)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func compatibilityCard(_ category: FormatCategory) -> some View {
        let columns = FormatCatalog.matrixColumns[category] ?? []
        let rows = FormatCatalog.inCategory(category)
        let columnWidth: CGFloat = columns.count >= 10 ? 28 : (columns.count > 6 ? 42 : 110)
        let labelWidth: CGFloat = columns.count >= 10 ? 46 : 48

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: category.symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.68))
                    .frame(width: 16)
                Text(category.title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.86))
            }

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.28))
                        .frame(width: labelWidth, alignment: .center)
                    ForEach(columns, id: \.self) { column in
                        Text(FormatCatalog.displayName(column))
                            .font(.system(size: columns.count >= 10 ? 7.2 : 8.2, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.44))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(width: columnWidth, height: 22)
                            .overlay(alignment: .trailing) {
                                Rectangle().fill(hairline).frame(width: 0.5)
                            }
                    }
                }
                .overlay(alignment: .bottom) {
                    Rectangle().fill(hairline).frame(height: 0.5)
                }

                ForEach(rows) { row in
                    HStack(spacing: 0) {
                        Text(row.name)
                            .font(.system(size: columns.count >= 10 ? 8.2 : 9.6, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.84))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .frame(width: labelWidth, alignment: .leading)
                            .padding(.leading, 5)
                        ForEach(columns, id: \.self) { column in
                            Group {
                                if row.outputs.contains(column) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 8.5, weight: .semibold))
                                        .foregroundStyle(Color.white.opacity(0.80))
                                } else {
                                    Text("–")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color.white.opacity(0.22))
                                }
                            }
                            .frame(width: columnWidth, height: 22)
                            .overlay(alignment: .trailing) {
                                Rectangle().fill(hairline).frame(width: 0.5)
                            }
                        }
                    }
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(hairline).frame(height: 0.5)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(white: 0.105))
            )
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(white: 0.155))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.white.opacity(0.055), lineWidth: 1)
        )
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

            groupBox {
                aboutLine("Formats", "7 families · 47 formats")
                divider
                aboutLine("Wheel", "7 conversions · 6 tools · 6 actions")
                divider
                aboutLine("Engines", "Images, PDF, subtitles and archives")
                divider
                HStack(spacing: 14) {
                    linkButton("GitHub", "https://github.com/j4yop/DragConvert")
                    linkButton("Releases", "https://github.com/j4yop/DragConvert/releases")
                    linkButton("License", "https://github.com/j4yop/DragConvert/blob/main/LICENSE")
                    Spacer()
                }
                .frame(height: 28)
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)

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

    private func aboutLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.82))
                .frame(width: 58, alignment: .leading)
            Text(value)
                .font(.system(size: 10.5))
                .foregroundStyle(Color.white.opacity(0.52))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 27)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
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
    let fontSize: CGFloat
    let background: Color
    let onSelect: (String) -> Void

    init(
        title: String,
        width: CGFloat,
        options: [PopupOption],
        fontSize: CGFloat = 10.5,
        background: Color = Color(white: 0.205),
        onSelect: @escaping (String) -> Void
    ) {
        self.title = title
        self.width = width
        self.options = options
        self.fontSize = fontSize
        self.background = background
        self.onSelect = onSelect
    }

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
                    .font(.system(size: fontSize, weight: .medium))
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
                    .fill(background)
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
