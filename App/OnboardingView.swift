import SwiftUI

// MARK: - Model

private struct OnboardingStep {
    let text: String
    let keys: [String]
}

private struct OnboardingPage {
    let title: String
    let body: String
    let steps: [OnboardingStep]
    let labels: [String]
    let highlighted: Int
}

// MARK: - View

struct OnboardingView: View {
    var onFinish: () -> Void
    var initialPage: Int

    @State private var page: Int

    init(initialPage: Int = 0, onFinish: @escaping () -> Void) {
        self.initialPage = initialPage
        self.onFinish = onFinish
        _page = State(initialValue: min(max(initialPage, 0), 4))
    }
    @State private var folderGranted = FolderAccess.shared.isGranted
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    private let accent = Color(red: 1.0, green: 0.42, blue: 0.18)

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "File Converter",
            body: "Drag any file in Finder, then hold Shift. The wheel appears at your pointer with only the formats that file can become.",
            steps: [
                OnboardingStep(text: "Drag files", keys: []),
                OnboardingStep(text: "Tap", keys: ["⇧"]),
                OnboardingStep(text: "Drop on a format", keys: [])
            ],
            labels: ["JPG", "PNG", "PDF", "TXT", "DOCX", "MP4", "ZIP"],
            highlighted: 0
        ),
        OnboardingPage(
            title: "File Tools",
            body: "Hold Option and Command to get the tools that make sense for that exact file: compress, crop, rotate, redact and more.",
            steps: [
                OnboardingStep(text: "Drag files", keys: []),
                OnboardingStep(text: "Tap", keys: ["⌥", "⌘"]),
                OnboardingStep(text: "Pick a tool", keys: [])
            ],
            labels: ["COMPRESS", "CROP", "RESIZE", "ROTATE", "ANNOTATE", "REDACT", "META"],
            highlighted: 1
        ),
        OnboardingPage(
            title: "File Actions",
            body: "Hold Control for actions that don’t convert anything: AirDrop, Float, Copy, Move, Copy Path and Terminal.",
            steps: [
                OnboardingStep(text: "Drag files", keys: []),
                OnboardingStep(text: "Tap", keys: ["⌃"]),
                OnboardingStep(text: "Pick an action", keys: [])
            ],
            labels: ["AIRDROP", "FLOAT", "COPY", "MOVE", "PATH", "TERMINAL", "SHARE"],
            highlighted: 0
        ),
        OnboardingPage(
            title: "Folder access",
            body: "Results are saved next to the originals. Allow your home folder once so macOS doesn’t ask again.",
            steps: [],
            labels: ["FOLDER", "ACCESS", "ONCE", "SAFE", "LOCAL", "PRIVATE", "FAST"],
            highlighted: 4
        ),
        OnboardingPage(
            title: "Finish setup",
            body: "Launch DragConvert at login, then drag a file and hold a key. Everything runs on this Mac.",
            steps: [],
            labels: ["READY", "LOCAL", "PRIVATE", "FAST", "SIMPLE", "NATIVE", "QUIET"],
            highlighted: 0
        )
    ]

    private var current: OnboardingPage { pages[page] }

    var body: some View {
        HStack(spacing: 32) {
            WheelGraphic(
                labels: current.labels,
                highlighted: current.highlighted
            )
            .frame(width: 250, height: 250)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: page)

            VStack(alignment: .leading, spacing: 12) {
                if page > 0 {
                    Button {
                        page -= 1
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }

                Text(current.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                Text(current.body)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)

                if !current.steps.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(current.steps.enumerated()), id: \.offset) { index, step in
                            HStack(spacing: 8) {
                                Text("\(index + 1).")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.55))
                                    .frame(width: 16, alignment: .trailing)
                                Text(step.text)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white)
                                ForEach(step.keys, id: \.self) { key in
                                    KeycapView(text: key)
                                }
                            }
                        }
                    }
                    .padding(.top, 2)
                }

                if page == 3 {
                    folderSection
                        .padding(.top, 4)
                }

                if page == 4 {
                    finishSection
                        .padding(.top, 4)
                }

                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    HStack(spacing: 6) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(index == page ? accent : Color.white.opacity(0.35))
                                .frame(width: 6, height: 6)
                        }
                    }

                    Button(page == 4 ? "Done" : "Continue") {
                        if page == 4 {
                            onFinish()
                        } else {
                            page += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .controlSize(.large)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: 380, maxHeight: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 36)
        .padding(.top, 42)
        .padding(.bottom, 30)
        .frame(width: 780, height: 430)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.80, blue: 0.58),
                    Color(red: 0.90, green: 0.45, blue: 0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(Capsule())
    }

    private var folderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if folderGranted {
                Label("Home folder access granted", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
            } else {
                Button("Allow Folder Access") {
                    folderGranted = FolderAccess.shared.ensureAccess()
                }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.18))
                .controlSize(.regular)

                Text("You can also grant it later from the menu bar.")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private var finishSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .toggleStyle(.switch)
                .onChange(of: launchAtLogin) { value in
                    LaunchAtLogin.set(value)
                }

            Text("Free for your first 20 files · one-time unlock after.")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

// MARK: - Wheel

private struct KeycapView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .frame(minWidth: 24, minHeight: 22)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.black.opacity(0.72))
            )
            .foregroundStyle(.white)
    }
}

private struct WheelGraphic: View {
    let labels: [String]
    let highlighted: Int

    private let accent = Color(red: 1.0, green: 0.42, blue: 0.18)

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let outer = size / 2 - 4
            let inner = outer * 0.38
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)

            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.10))
                    .frame(width: outer * 2 + 8, height: outer * 2 + 8)

                ForEach(0..<labels.count, id: \.self) { index in
                    WedgeShape(
                        index: index,
                        count: labels.count,
                        innerRatio: 0.38,
                        gap: 2
                    )
                    .fill(index == highlighted ? accent : Color.white.opacity(0.82))
                    .overlay(
                        WedgeShape(
                            index: index,
                            count: labels.count,
                            innerRatio: 0.38,
                            gap: 2
                        )
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )

                    Text(labels[index])
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(index == highlighted ? .white : .black.opacity(0.75))
                        .position(labelPoint(
                            index: index,
                            count: labels.count,
                            center: center,
                            radius: (inner + outer) / 2
                        ))
                }

                Circle()
                    .fill(accent.opacity(0.95))
                    .frame(width: inner * 1.5, height: inner * 1.5)
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 2)

                Text("DROP")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func labelPoint(
        index: Int,
        count: Int,
        center: CGPoint,
        radius: CGFloat
    ) -> CGPoint {
        let angle = (-90.0 + 360.0 / Double(count) * Double(index)) * .pi / 180
        return CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )
    }
}

private struct WedgeShape: Shape {
    let index: Int
    let count: Int
    let innerRatio: CGFloat
    let gap: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2 - 4
        let inner = outer * innerRatio
        let step = 360.0 / Double(max(1, count))
        let start = -90 - step / 2 + gap / 2 + step * Double(index)
        let end = start + step - gap

        var path = Path()
        path.addArc(
            center: center,
            radius: outer,
            startAngle: .degrees(start),
            endAngle: .degrees(end),
            clockwise: false
        )
        path.addArc(
            center: center,
            radius: inner,
            startAngle: .degrees(end),
            endAngle: .degrees(start),
            clockwise: true
        )
        path.closeSubpath()
        return path
    }
}
