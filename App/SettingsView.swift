import SwiftUI
import JobCore
import CapabilityGraph

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general, wheel, actions, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .wheel: return "The Wheel"
        case .actions: return "Actions"
        case .about: return "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .wheel: return "circle.hexagongrid.fill"
        case .actions: return "bolt.horizontal.circle"
        case .about: return "info.circle"
        }
    }

    var subtitle: String {
        switch self {
        case .general: return "Startup, feedback and how results appear."
        case .wheel: return "Choose the keys and see the wheel you will use."
        case .actions: return "Clipboard, folders and the terminal handoff."
        case .about: return "Version, source and the GPL-3.0 licence."
        }
    }
}

struct SettingsView: View {
    @AppStorage("wheelConvertShortcut") private var convert = WheelShortcut.shift.rawValue
    @AppStorage("wheelToolsShortcut") private var tools = WheelShortcut.optionShift.rawValue
    @AppStorage("wheelActionsShortcut") private var actions = WheelShortcut.control.rawValue
    @AppStorage("soundEnabled") private var sound = true
    @AppStorage("hapticsEnabled") private var haptics = true
    @AppStorage("revealOnFinish") private var reveal = true
    @AppStorage("terminalBundleID") private var terminal = TerminalApps.selectedBundleID
    @AppStorage("conflictPolicy") private var conflict = ConflictPolicy.rename.rawValue
    @AppStorage("showMenuBarIcon") private var showMenuBar = true
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var section: SettingsSection

    init() {
        if let index = CommandLine.arguments.firstIndex(of: "--settings-demo"),
           index + 1 < CommandLine.arguments.count,
           let value = SettingsSection(rawValue: CommandLine.arguments[index + 1]) {
            _section = State(initialValue: value)
        } else {
            _section = State(initialValue: .general)
        }
    }

    private let accent = Color(red: 1.0, green: 0.322, blue: 0.0)

    private var hasDuplicateShortcut: Bool {
        Set([convert, tools, actions]).count < 3
    }

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.5.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "6"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            detail
        }
        .frame(width: 760, height: 680)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .preferredColorScheme(.light)
        .onAppear {
            DestinationPolicy.policy = ConflictPolicy(rawValue: conflict) ?? .rename
        }
        .onChange(of: conflict) { value in
            DestinationPolicy.policy = ConflictPolicy(rawValue: value) ?? .rename
        }
        .onChange(of: showMenuBar) { value in
            UserDefaults.standard.set(value, forKey: "showMenuBarIcon")
            NotificationCenter.default.post(
                name: .menuBarVisibilityChanged,
                object: value
            )
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 11) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 1) {
                    Text("DragConvert")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("SETTINGS")
                        .font(.system(size: 8.5, weight: .bold))
                        .tracking(1.3)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 30)
            .padding(.bottom, 20)

            ForEach(SettingsSection.allCases) { item in
                Button {
                    section = item
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 18)
                            .foregroundStyle(section == item ? accent : .secondary)
                        Text(item.title)
                            .font(.system(size: 12.5, weight: section == item ? .semibold : .medium))
                            .foregroundStyle(section == item ? Color.black.opacity(0.82) : .secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 11)
                    .frame(height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(section == item ? Color.white.opacity(0.74) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                section == item ? Color.white.opacity(0.9) : Color.clear,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 2) {
                Text(version)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("GPL-3.0-only · free forever")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 14)
        .frame(width: 208)
        .background(Color.white.opacity(0.18))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.black.opacity(0.055))
                .frame(width: 1)
        }
    }

    // MARK: Detail

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.title)
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.84))
                    Text(section.subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)

                switch section {
                case .general:
                    general
                case .wheel:
                    wheel
                case .actions:
                    actionsTab
                case .about:
                    about
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 30)
            .padding(.bottom, 26)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.visible)
    }

    private var general: some View {
        VStack(spacing: 12) {
            card("Startup", "Keep DragConvert ready without thinking about it.") {
                toggleRow("Launch at login", "Start quietly after you sign in.", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { value in
                        LaunchAtLogin.set(value)
                    }
                divider
                toggleRow(
                    "Show in menu bar",
                    "Turn this off to use a Dock icon instead.",
                    isOn: $showMenuBar
                )
            }

            card("Feedback", "The small confirmations that make the wheel feel physical.") {
                toggleRow("Sound effects", "A soft tick on hover and a chime on completion.", isOn: $sound)
                divider
                toggleRow("Hover haptics", "A light alignment tap as the pointer crosses a wedge.", isOn: $haptics)
            }

            card("Results", "DragConvert always writes a new copy beside the original.") {
                toggleRow("Reveal in Finder", "Select the finished files when a job completes.", isOn: $reveal)
                divider
                settingsRow("When a file exists", "Keep both or replace only generated results.") {
                    Picker("", selection: $conflict) {
                        Text("Keep both").tag(ConflictPolicy.rename.rawValue)
                        Text("Replace").tag(ConflictPolicy.replace.rawValue)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 150, alignment: .trailing)
                }
            }
        }
    }

    private var wheel: some View {
        VStack(spacing: 12) {
            card("Shortcuts", "Tap a key once while dragging. Release it and the wheel stays open.") {
                shortcutRow("Convert", shortcut: $convert)
                divider
                shortcutRow("Tools", shortcut: $tools)
                divider
                shortcutRow("Actions", shortcut: $actions)

                if hasDuplicateShortcut {
                    Label("Give each wheel its own shortcut.", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.orange)
                        .padding(.top, 2)
                }
            }

            card("Preview", "The hovered wedge turns the same vivid orange as the live wheel.") {
                HStack(spacing: 20) {
                    WheelGraphic(
                        labels: ["JPG", "PNG", "HEIC", "TIFF", "AVIF", "BMP", "PDF", "TXT"],
                        highlighted: 5
                    )
                    .frame(width: 176, height: 176)
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 4)

                    VStack(alignment: .leading, spacing: 7) {
                        Text("A quiet, physical menu")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Text("The centre holds the file preview and size. Move outward to a wedge, then let go.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Press  ,  while the wheel is open to come back here.")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(accent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            card("Behaviour", "Built for deliberate choices, not accidental drops.") {
                Text("The wheel blooms from the pointer, stays pinned after you release the modifier, and closes only when you drop or press Esc.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var actionsTab: some View {
        VStack(spacing: 12) {
            card("Terminal", "The Terminal action opens the selected folder in the app you choose.") {
                settingsRow("Open in", "Only installed terminal apps are listed.") {
                    Picker("", selection: $terminal) {
                        ForEach(TerminalApps.installed) { app in
                            Text(app.name).tag(app.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 170, alignment: .trailing)
                }
            }

            card("Clipboard and folders", "The actions never modify the original.") {
                actionRow("Copy", "Puts the selected file URLs on the clipboard, ready for Finder.")
                divider
                actionRow("Move", "Asks for a destination folder and moves the originals there.")
                divider
                actionRow("Copy Path", "Copies one POSIX path per line.")
                divider
                actionRow("Float", "Parks the selection on a floating shelf you can drag from.")
            }
        }
    }

    private var about: some View {
        VStack(spacing: 12) {
            card("DragConvert", "A free, local-first file wheel for macOS.") {
                HStack(spacing: 18) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 72, height: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DragConvert")
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                        Text(version)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text("GPL-3.0-only · free forever")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(accent)
                    }
                    Spacer()
                }

                Text("No account, no telemetry, no network entitlement. Files stay on this Mac and results are written beside the original.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    linkButton("GitHub", "https://github.com/j4yop/DragConvert")
                    linkButton("Releases", "https://github.com/j4yop/DragConvert/releases")
                    linkButton("GPL-3.0", "https://github.com/j4yop/DragConvert/blob/main/LICENSE")
                }
            }

            card("First-run", "Need the tour again?") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show the welcome tour")
                            .font(.system(size: 12, weight: .medium))
                        Text("Wheel practice, folder access and launch at login.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Show Tour") {
                        UserDefaults.standard.set(false, forKey: "hasSeenWelcome")
                        NotificationCenter.default.post(name: .showOnboarding, object: nil)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .controlSize(.small)
                }
            }

            Text("Tangerine is a separate product by Leap Studio. DragConvert is not affiliated with it.")
                .font(.system(size: 9.5))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: Components

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.965, blue: 0.925),
                    Color(red: 0.995, green: 0.86, blue: 0.74)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color.white.opacity(0.22))
                .frame(width: 420, height: 420)
                .offset(x: 260, y: -260)
            Circle()
                .fill(Color(red: 1.0, green: 0.70, blue: 0.45).opacity(0.13))
                .frame(width: 300, height: 300)
                .offset(x: 210, y: 300)
        }
    }

    private func card<Content: View>(
        _ title: String,
        _ subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.82))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.white.opacity(0.64))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Color.white.opacity(0.8), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.045), radius: 10, y: 4)
    }

    private func toggleRow(_ title: String, _ detail: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(accent)
        }
    }

    private func settingsRow<Control: View>(
        _ title: String,
        _ detail: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            control()
        }
    }

    private func shortcutRow(_ title: String, shortcut: Binding<String>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .medium))
            Spacer()
            Picker("", selection: shortcut) {
                ForEach(WheelShortcut.allCases, id: \.rawValue) { item in
                    Text(item.title).tag(item.rawValue)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 220, alignment: .trailing)
        }
    }

    private func actionRow(_ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.8))
                .frame(width: 72, alignment: .leading)
            Text(detail)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.07))
            .frame(height: 1)
    }

    private func linkButton(_ title: String, _ url: String) -> some View {
        Button(title) {
            guard let url = URL(string: url) else { return }
            NSWorkspace.shared.open(url)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(accent)
    }
}

final class SettingsWindowController: NSWindowController {
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 680),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "DragConvert Settings"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.contentViewController = NSHostingController(rootView: SettingsView())
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("not used") }
}
