import AppKit
import SwiftUI

struct AboutView: View {
    private let accent = Color(red: 1.0, green: 0.322, blue: 0.0)

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.5.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "6"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 88, height: 88)

            Text("DragConvert")
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.84))
            Text(version)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text("A free, local-first file wheel for macOS.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.78))

            Text("Drag a file, hold ⇧ for formats, ⇧⌥ for tools, or ⌃ for actions. Results are saved beside the original.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Label("No network entitlement — files stay on this Mac", systemImage: "wifi.slash")
                Label("GPL-3.0-only · no account, no telemetry", systemImage: "checkmark.seal")
                Label("Images and PDF today; more families on the roadmap", systemImage: "clock")
            }
            .font(.system(size: 11.5))
            .foregroundStyle(Color.black.opacity(0.72))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.52))
            )

            HStack(spacing: 8) {
                link("GitHub", "https://github.com/j4yop/DragConvert")
                link("Releases", "https://github.com/j4yop/DragConvert/releases")
                link("GPL-3.0", "https://github.com/j4yop/DragConvert/blob/main/LICENSE")
            }
            .padding(.top, 2)

            Spacer(minLength: 0)

            Text("Tangerine is a separate product by Leap Studio. DragConvert is not affiliated with it.")
                .font(.system(size: 9.5))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 30)
        .padding(.top, 28)
        .padding(.bottom, 20)
        .frame(width: 540, height: 520)
        .background(
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.965, blue: 0.925),
                        Color(red: 0.995, green: 0.85, blue: 0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(Color.white.opacity(0.24))
                    .frame(width: 300, height: 300)
                    .offset(x: 190, y: -230)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .preferredColorScheme(.light)
    }

    private func link(_ title: String, _ url: String) -> some View {
        Button(title) {
            guard let url = URL(string: url) else { return }
            NSWorkspace.shared.open(url)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(accent)
    }
}

final class AboutWindowController: NSWindowController {
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 520),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "About DragConvert"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.contentViewController = NSHostingController(rootView: AboutView())
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("not used") }
}
