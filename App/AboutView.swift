import AppKit
import SwiftUI

struct AboutView: View {
    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.4.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "5"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            Text("DragConvert")
                .font(.system(size: 27, weight: .bold))
            Text(version)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text("A free, open-source file wheel for macOS.")
                .font(.system(size: 13, weight: .medium))

            Text("Drag a file, hold ⇧ for formats, ⇧⌥ for tools, or ⌃ for actions. Results are saved beside the original.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Label("No network entitlement — files stay on this Mac", systemImage: "wifi.slash")
                Label("GPL-3.0 licensed, no account, no telemetry", systemImage: "checkmark.seal")
                Label("Images and PDF today; more families on the roadmap", systemImage: "clock")
            }
            .font(.system(size: 11.5))
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                link("GitHub", "https://github.com/j4yop/DragConvert")
                link("Updates", "https://github.com/j4yop/DragConvert/releases")
                link("GPL-3.0 Licence", "https://github.com/j4yop/DragConvert/blob/main/LICENSE")
            }
            .padding(.top, 2)

            Spacer(minLength: 0)

            Text("Tangerine is a separate product by Leap Studio. DragConvert is not affiliated with it.")
                .font(.system(size: 9.5))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 30)
        .padding(.top, 26)
        .padding(.bottom, 20)
        .frame(width: 520, height: 500)
    }

    private func link(_ title: String, _ url: String) -> some View {
        Button(title) {
            guard let url = URL(string: url) else { return }
            NSWorkspace.shared.open(url)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

final class AboutWindowController: NSWindowController {
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About DragConvert"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: AboutView())
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("not used") }
}
