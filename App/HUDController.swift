import AppKit

/// Floating progress toast, bottom-right of the active screen.
/// Non-activating, so it never steals focus from Finder.
@MainActor
final class HUDController {
    var onCancel: (() -> Void)?

    private let panel = HUDPanel()
    private let content = HUDContentView()
    private var dismissWork: DispatchWorkItem?

    init() {
        panel.contentView = content
        content.onCancel = { [weak self] in self?.onCancel?() }
    }

    func show(title: String, subtitle: String) {
        dismissWork?.cancel()
        content.apply(title: title, subtitle: subtitle, state: .running)
        position()
        panel.orderFrontRegardless()
    }

    func update(subtitle: String) {
        content.subtitle = subtitle
    }

    func succeed(title: String, subtitle: String) {
        content.apply(title: title, subtitle: subtitle, state: .success)
        scheduleDismiss(after: 1.8)
    }

    func fail(_ message: String) {
        content.apply(title: "Couldn’t finish", subtitle: message, state: .failure)
        scheduleDismiss(after: 4.5)
    }

    func note(title: String, subtitle: String) {
        dismissWork?.cancel()
        content.apply(title: title, subtitle: subtitle, state: .info)
        position()
        panel.orderFrontRegardless()
        scheduleDismiss(after: 2.8)
    }

    func hide() {
        dismissWork?.cancel()
        panel.orderOut(nil)
    }

    private func scheduleDismiss(after seconds: TimeInterval) {
        dismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.panel.orderOut(nil) }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func position() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(
            x: visible.maxX - size.width - 24,
            y: visible.minY + 24
        ))
    }
}

final class HUDPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 92),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        appearance = NSAppearance(named: .darkAqua)
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        ignoresMouseEvents = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class HUDContentView: NSView {
    enum State { case running, success, failure, info }

    var onCancel: (() -> Void)?
    private(set) var title = ""

    var subtitle: String {
        get { subtitleLabel.stringValue }
        set { subtitleLabel.stringValue = newValue }
    }

    private let effect = NSVisualEffectView()
    private let icon = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let progress = NSProgressIndicator()
    private let cancelButton = NSButton()

    private let accent = NSColor(srgbRed: 1.0, green: 0.42, blue: 0.18, alpha: 1.0)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 18
        layer?.masksToBounds = true

        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.translatesAutoresizingMaskIntoConstraints = false
        addSubview(effect)

        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitleLabel)

        progress.style = .bar
        progress.controlSize = .small
        progress.isIndeterminate = true
        progress.translatesAutoresizingMaskIntoConstraints = false
        addSubview(progress)

        cancelButton.image = NSImage(
            systemSymbolName: "xmark.circle.fill",
            accessibilityDescription: "Cancel"
        )
        cancelButton.isBordered = false
        cancelButton.bezelStyle = .inline
        cancelButton.contentTintColor = .secondaryLabelColor
        cancelButton.target = self
        cancelButton.action = #selector(cancelTapped)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cancelButton)

        NSLayoutConstraint.activate([
            effect.leadingAnchor.constraint(equalTo: leadingAnchor),
            effect.trailingAnchor.constraint(equalTo: trailingAnchor),
            effect.topAnchor.constraint(equalTo: topAnchor),
            effect.bottomAnchor.constraint(equalTo: bottomAnchor),

            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            icon.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),

            cancelButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            cancelButton.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            cancelButton.widthAnchor.constraint(equalToConstant: 20),
            cancelButton.heightAnchor.constraint(equalToConstant: 20),

            titleLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: cancelButton.leadingAnchor, constant: -8),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            progress.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            progress.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            progress.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            progress.heightAnchor.constraint(equalToConstant: 4)
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func apply(title: String, subtitle: String, state: State) {
        self.title = title
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle

        switch state {
        case .running:
            icon.image = symbol("arrow.down.doc.fill", color: accent)
            cancelButton.isHidden = false
            progress.isIndeterminate = true
            progress.startAnimation(nil)
        case .success:
            icon.image = symbol("checkmark.circle.fill", color: .systemGreen)
            cancelButton.isHidden = true
            progress.stopAnimation(nil)
            progress.isIndeterminate = false
            progress.doubleValue = 100
        case .failure:
            icon.image = symbol("exclamationmark.triangle.fill", color: .systemOrange)
            cancelButton.isHidden = true
            progress.stopAnimation(nil)
            progress.isIndeterminate = false
            progress.doubleValue = 0
        case .info:
            icon.image = symbol("sparkles", color: accent)
            cancelButton.isHidden = true
            progress.stopAnimation(nil)
            progress.isIndeterminate = false
            progress.doubleValue = 0
        }
    }

    private func symbol(_ name: String, color: NSColor) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
    }

    @objc private func cancelTapped() {
        onCancel?()
    }
}
