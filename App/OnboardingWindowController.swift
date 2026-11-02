import AppKit
import SwiftUI

final class OnboardingWindowController: NSWindowController {
    var onFinish: (() -> Void)?

    init(initialPage: Int = 0) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 430),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to DragConvert"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.standardWindowButton(.zoomButton)?.isHidden = true
        super.init(window: window)

        window.contentView = NSHostingView(
            rootView: OnboardingView(initialPage: initialPage, onFinish: { [weak self] in self?.finish() })
        )
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func finish() {
        onFinish?()
        close()
    }
}
