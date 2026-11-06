import AppKit
import WheelUI

/// Compact, dark glass progress card. It sits near the centre of the active
/// screen, like the reference's conversion readout, and never steals focus.
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
        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
        } else {
            panel.alphaValue = 1
            panel.orderFrontRegardless()
        }
    }

    func update(subtitle: String) {
        content.subtitle = subtitle
    }

    func succeed(title: String, subtitle: String) {
        content.apply(title: title, subtitle: subtitle, state: .success)
        Feedback.shared.success()
        scheduleDismiss(after: 1.9)
    }

    func fail(_ message: String) {
        content.apply(title: "Couldn’t finish", subtitle: message, state: .failure)
        Feedback.shared.failure()
        scheduleDismiss(after: 4.5)
    }

    func note(title: String, subtitle: String) {
        dismissWork?.cancel()
        content.apply(title: title, subtitle: subtitle, state: .info)
        Feedback.shared.note()
        position()
        panel.orderFrontRegardless()
        scheduleDismiss(after: 2.8)
    }

    func hide() {
        dismissWork?.cancel()
        content.stop()
        panel.orderOut(nil)
        panel.alphaValue = 1
    }

    private func scheduleDismiss(after seconds: TimeInterval) {
        dismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                self.panel.animator().alphaValue = 0
            } completionHandler: {
                Task { @MainActor in
                    self.panel.orderOut(nil)
                    self.panel.alphaValue = 1
                }
            }
        }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func position() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY + 40
        ))
    }
}

final class HUDPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 330, height: 78),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        appearance = NSAppearance(named: .darkAqua)
        level = .screenSaver
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
    private let tint = NSView()
    private let icon = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let progress = HUDProgressView()
    private let cancelButton = NSButton()

    private let accent = NSColor(srgbRed: 1.0, green: 0.322, blue: 0.0, alpha: 1.0)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.10).cgColor

        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.appearance = NSAppearance(named: .darkAqua)
        effect.translatesAutoresizingMaskIntoConstraints = false
        addSubview(effect)

        tint.wantsLayer = true
        tint.layer?.backgroundColor = NSColor(calibratedWhite: 0.015, alpha: 0.82).cgColor
        tint.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tint)

        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.wantsLayer = true
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)

        titleLabel.font = .systemFont(ofSize: 12.5, weight: .semibold)
        titleLabel.textColor = NSColor.white.withAlphaComponent(0.94)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        subtitleLabel.font = .systemFont(ofSize: 10.5)
        subtitleLabel.textColor = NSColor.white.withAlphaComponent(0.52)
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitleLabel)

        progress.translatesAutoresizingMaskIntoConstraints = false
        addSubview(progress)

        cancelButton.image = NSImage(
            systemSymbolName: "xmark",
            accessibilityDescription: "Cancel"
        )
        cancelButton.isBordered = false
        cancelButton.bezelStyle = .inline
        cancelButton.contentTintColor = NSColor.white.withAlphaComponent(0.45)
        cancelButton.target = self
        cancelButton.action = #selector(cancelTapped)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cancelButton)

        NSLayoutConstraint.activate([
            effect.leadingAnchor.constraint(equalTo: leadingAnchor),
            effect.trailingAnchor.constraint(equalTo: trailingAnchor),
            effect.topAnchor.constraint(equalTo: topAnchor),
            effect.bottomAnchor.constraint(equalTo: bottomAnchor),

            tint.leadingAnchor.constraint(equalTo: leadingAnchor),
            tint.trailingAnchor.constraint(equalTo: trailingAnchor),
            tint.topAnchor.constraint(equalTo: topAnchor),
            tint.bottomAnchor.constraint(equalTo: bottomAnchor),

            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            icon.topAnchor.constraint(equalTo: topAnchor, constant: 13),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18),

            cancelButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            cancelButton.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            cancelButton.widthAnchor.constraint(equalToConstant: 18),
            cancelButton.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 11),
            titleLabel.trailingAnchor.constraint(equalTo: cancelButton.leadingAnchor, constant: -8),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 1),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            progress.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            progress.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            progress.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            progress.heightAnchor.constraint(equalToConstant: 3)
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func apply(title: String, subtitle: String, state: State) {
        self.title = title
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle
        icon.layer?.removeAllAnimations()
        layer?.removeAnimation(forKey: "shake")

        switch state {
        case .running:
            icon.image = symbol("arrow.down.doc.fill", color: accent)
            cancelButton.isHidden = false
            progress.isHidden = false
            progress.color = accent
            progress.start()
            layer?.borderColor = NSColor.white.withAlphaComponent(0.10).cgColor
        case .success:
            icon.image = statusIcon("checkmark", background: .systemGreen)
            cancelButton.isHidden = true
            progress.isHidden = false
            progress.color = .systemGreen
            progress.stop()
            progress.value = 1
            layer?.borderColor = NSColor.systemGreen.withAlphaComponent(0.30).cgColor
            animatePop()
        case .failure:
            icon.image = statusIcon("xmark", background: .systemRed)
            cancelButton.isHidden = true
            progress.isHidden = false
            progress.color = .systemRed
            progress.stop()
            progress.value = 0
            layer?.borderColor = NSColor.systemRed.withAlphaComponent(0.36).cgColor
            animateShake()
        case .info:
            icon.image = symbol("sparkles", color: accent)
            cancelButton.isHidden = true
            progress.isHidden = true
            progress.stop()
            layer?.borderColor = NSColor.white.withAlphaComponent(0.10).cgColor
        }
    }

    func stop() {
        progress.stop()
    }

    private func animatePop() {
        let pop = CAKeyframeAnimation(keyPath: "transform.scale")
        pop.values = [0.62, 1.14, 1.0]
        pop.keyTimes = [0, 0.55, 1]
        pop.duration = 0.30
        pop.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]
        icon.layer?.add(pop, forKey: "pop")
    }

    private func animateShake() {
        let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shake.values = [0, -6, 5, -4, 3, -1.5, 0]
        shake.keyTimes = [0, 0.14, 0.30, 0.46, 0.62, 0.80, 1]
        shake.duration = 0.40
        layer?.add(shake, forKey: "shake")
    }

    private func symbol(_ name: String, color: NSColor) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
    }

    private func statusIcon(_ name: String, background: NSColor) -> NSImage? {
        NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            background.setFill()
            NSBezierPath(ovalIn: rect).fill()
            guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
                return true
            }
            let configuration = NSImage.SymbolConfiguration(pointSize: 9, weight: .bold)
                .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
            guard let symbol = base.withSymbolConfiguration(configuration) else { return true }
            let size = symbol.size
            symbol.draw(in: NSRect(
                x: rect.midX - size.width / 2,
                y: rect.midY - size.height / 2,
                width: size.width,
                height: size.height
            ))
            return true
        }
    }

    @objc private func cancelTapped() {
        onCancel?()
    }
}

private final class HUDProgressView: NSView {
    var color = NSColor(srgbRed: 1.0, green: 0.322, blue: 0.0, alpha: 1.0) {
        didSet { needsDisplay = true }
    }
    private var running = false
    private var phase: CGFloat = 0
    private var timer: Timer?

    var value: Double = 0 { didSet { needsDisplay = true } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    deinit {
        timer?.invalidate()
    }

    func start() {
        guard !running else { return }
        running = true
        phase = 0
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self, self.running else { timer.invalidate(); return }
            self.phase = (self.phase + 0.018).truncatingRemainder(dividingBy: 1)
            self.needsDisplay = true
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        running = false
        timer?.invalidate()
        timer = nil
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let track = NSBezierPath(
            roundedRect: bounds,
            xRadius: bounds.height / 2,
            yRadius: bounds.height / 2
        )
        NSColor.white.withAlphaComponent(0.13).setFill()
        track.fill()

        let fill: NSRect
        if running {
            let width = bounds.width * 0.26
            let travel = bounds.width - width
            let x = travel * phase
            fill = NSRect(x: x, y: 0, width: width, height: bounds.height)
        } else {
            fill = NSRect(
                x: 0,
                y: 0,
                width: bounds.width * min(max(value, 0), 1),
                height: bounds.height
            )
        }
        guard fill.width > 0 else { return }
        let bar = NSBezierPath(
            roundedRect: fill,
            xRadius: bounds.height / 2,
            yRadius: bounds.height / 2
        )
        color.setFill()
        bar.fill()
    }
}
