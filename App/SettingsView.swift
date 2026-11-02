import SwiftUI
import JobCore
import CapabilityGraph

struct SettingsView: View {
    @AppStorage("wheelConvertShortcut") private var convert = WheelShortcut.shift.rawValue
    @AppStorage("wheelToolsShortcut") private var tools = WheelShortcut.optionShift.rawValue
    @AppStorage("wheelActionsShortcut") private var actions = WheelShortcut.control.rawValue
    @AppStorage("soundEnabled") private var sound = true
    @AppStorage("hapticsEnabled") private var haptics = true
    @AppStorage("revealOnFinish") private var reveal = true
    @AppStorage("terminalBundleID") private var terminal = TerminalApps.selectedBundleID
    @AppStorage("conflictPolicy") private var conflict = ConflictPolicy.rename.rawValue
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    private var hasDuplicateShortcut: Bool {
        Set([convert, tools, actions]).count < 3
    }

    var body: some View {
        Form {
            Section("Wheel shortcuts") {
                picker("Convert", $convert)
                picker("Tools", $tools)
                picker("Actions", $actions)

                if hasDuplicateShortcut {
                    Label(
                        "Two wheels share a shortcut. Give each one its own.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                }
            }

            Section("Feedback") {
                Toggle("Play a sound when a file is saved", isOn: $sound)
                Toggle("Hover haptics", isOn: $haptics)
                Toggle("Reveal the result in Finder", isOn: $reveal)
            }

            Section("Actions") {
                Picker("Open Terminal in", selection: $terminal) {
                    ForEach(TerminalApps.installed) { app in
                        Text(app.name).tag(app.id)
                    }
                }

                Text("The Terminal action uses this app. Copy puts the selected file URLs on the clipboard.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Section("Files") {
                Picker("When a file already exists", selection: $conflict) {
                    Text("Keep both (add a number)")
                        .tag(ConflictPolicy.rename.rawValue)
                    Text("Replace the existing file")
                        .tag(ConflictPolicy.replace.rawValue)
                }

                Text("Replace applies to generated results, never to the original input.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { value in
                        LaunchAtLogin.set(value)
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 700)
        .onAppear {
            DestinationPolicy.policy =
                ConflictPolicy(rawValue: conflict) ?? .rename
        }
        .onChange(of: conflict) { value in
            DestinationPolicy.policy =
                ConflictPolicy(rawValue: value) ?? .rename
        }
    }

    private func picker(_ title: String, _ selection: Binding<String>) -> some View {
        Picker(title, selection: selection) {
            ForEach(WheelShortcut.allCases, id: \.rawValue) { shortcut in
                Text(shortcut.title).tag(shortcut.rawValue)
            }
        }
        .pickerStyle(.menu)
    }
}

final class SettingsWindowController: NSWindowController {
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 700),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: SettingsView())
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("not used") }
}
