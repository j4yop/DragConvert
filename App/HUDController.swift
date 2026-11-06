import AppKit
import WheelUI

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
            x: visible.maxX - size.width - 24,
            y: visible.minY + 24
        ))
    }
}

final class HUDPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 372, height: 94),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        appearance = NSAppearance(named: .aqua)
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
    private let tint = NSView()
    private let icon = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let progress = HUDProgressView()
    private let cancelButton = NSButton()

    private let accent = NSColor(srgbRed: 1.0, green: 0.322, blue: 0.0, alpha: 1.0)
    private let ink = NSColor(calibratedWhite: 0.12, alpha: 0.92)
    private let muted = NSColor(calibratedWhite: 0.30, alpha: 0.72)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 18
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.55).cgColor

        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.appearance = NSAppearance(named: .aqua)
        effect.translatesAutoresizingMaskIntoConstraints = false
        addSubview(effect)

        tint.wantsLayer = true
        tint.layer?.backgroundColor = NSColor(
            srgbRed: 0.99, green: 0.94, blue: 0.88, alpha: 0.54
        ).cgColor
        tint.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tint)

        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.wantsLayer = true
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = ink
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = muted
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitleLabel)

        progress.translatesAutoresizingMaskIntoConstraints = false
        addSubview(progress)

        cancelButton.image = NSImage(
            systemSymbolName: "xmark.circle.fill",
            accessibilityDescription: "Cancel"
        )
        cancelButton.isBordered = false
        cancelButton.bezelStyle = .inline
        cancelButton.contentTintColor = muted
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

            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            icon.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22),

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
        icon.layer?.removeAllAnimations()
        layer?.removeAnimation(forKey: "shake")

        switch state {
        case .running:
            icon.image = statusIcon("arrow.down.doc.fill", background: accent)
            cancelButton.isHidden = false
            progress.isHidden = false
            progress.start()
            layer?.borderColor = NSColor.white.withAlphaComponent(0.55).cgColor
        case .success:
            icon.image = statusIcon("checkmark", background: .systemGreen)
            cancelButton.isHidden = true
            progress.isHidden = false
            progress.stop()
            progress.value = 1
            layer?.borderColor = NSColor.systemGreen.withAlphaComponent(0.35).cgColor
            animateSuccess()
        case .failure:
            icon.image = statusIcon("exclamationmark", background: .systemRed)
            cancelButton.isHidden = true
            progress.isHidden = false
            progress.stop()
            progress.value = 0
            layer?.borderColor = NSColor.systemRed.withAlphaComponent(0.42).cgColor
            animateFailure()
        case .info:
            icon.image = statusIcon("sparkles", background: accent)
            cancelButton.isHidden = true
            progress.isHidden = true
            progress.stop()
            layer?.borderColor = NSColor.white.withAlphaComponent(0.55).cgColor
        }
    }

    func stop() {
        progress.stop()
    }

    private func animateSuccess() {
        let pop = CAKeyframeAnimation(keyPath: "transform.scale")
        pop.values = [0.55, 1.16, 1.0]
        pop.keyTimes = [0, 0.55, 1]
        pop.duration = 0.34
        pop.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]
        icon.layer?.add(pop, forKey: "pop")

        let glow = CABasicAnimation(keyPath: "borderColor")
        glow.fromValue = NSColor.systemGreen.withAlphaComponent(0.85).cgColor
        glow.toValue = NSColor.systemGreen.withAlphaComponent(0.35).cgColor
        glow.duration = 0.55
        layer?.add(glow, forKey: "successGlow")
    }

    private func animateFailure() {
        let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shake.values = [0, -7, 6, -5, 4, -2, 0]
        shake.keyTimes = [0, 0.14, 0.30, 0.46, 0.62, 0.80, 1]
        shake.duration = 0.42
        layer?.add(shake, forKey: "shake")

        let flash = CABasicAnimation(keyPath: "borderColor")
        flash.fromValue = NSColor.systemRed.withAlphaComponent(0.9).cgColor
        flash.toValue = NSColor.systemRed.withAlphaComponent(0.42).cgColor
        flash.duration = 0.55
        layer?.add(flash, forKey: "failureFlash")
    }

    private func statusIcon(_ name: String, background: NSColor) -> NSImage? {
        NSImage(size: NSSize(width: 22, height: 22), flipped: false) { rect in
            background.setFill()
            NSBezierPath(ovalIn: rect).fill()
            guard let base = NSImage(
                systemSymbolName: name,
                accessibilityDescription: nil
            ) else { return true }
            let configuration = NSImage.SymbolConfiguration(pointSize: 11, weight: .bold)
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
    private let accent = NSColor(srgbRed: 1.0, green: 0.322, blue: 0.0, alpha: 1.0)
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
        NSColor(calibratedWhite: 0.22, alpha: 0.12).setFill()
        track.fill()

        let fill: NSRect
        if running {
            let width = bounds.width * 0.30
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
        accent.setFill()
        bar.fill()
    }
}
