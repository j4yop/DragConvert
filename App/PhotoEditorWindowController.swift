import AppKit
import ImageEngine
import JobCore

final class PhotoEditorWindowController: NSWindowController {
    var onApply: ((ImageAdjustSpec) -> Void)?

    private let preview: CGImage
    private let format: String
    private let imageView = NSImageView()

    private let brightnessSlider = NSSlider(value: 0, minValue: -100, maxValue: 100, target: nil, action: nil)
    private let contrastSlider = NSSlider(value: 0, minValue: -100, maxValue: 100, target: nil, action: nil)
    private let saturationSlider = NSSlider(value: 0, minValue: -100, maxValue: 100, target: nil, action: nil)
    private let warmthSlider = NSSlider(value: 0, minValue: -100, maxValue: 100, target: nil, action: nil)

    private let brightnessLabel = NSTextField(labelWithString: "0")
    private let contrastLabel = NSTextField(labelWithString: "0")
    private let saturationLabel = NSTextField(labelWithString: "0")
    private let warmthLabel = NSTextField(labelWithString: "0")

    init?(url: URL) {
        guard let preview = ImageConvertEngine.loadPreview(at: url, maxPixel: 1200) else {
            return nil
        }
        self.preview = preview
        let ext = url.pathExtension.lowercased()
        self.format = ["jpg", "jpeg", "png", "heic", "tiff"].contains(ext) ? ext : "png"

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 800),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Edit Photo"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)

        buildUI(url: url)
        updatePreview()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func buildUI(url: URL) {
        guard let window, let root = window.contentView else { return }

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.black.cgColor
        imageView.layer?.cornerRadius = 10
        imageView.layer?.masksToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.heightAnchor.constraint(equalToConstant: 420).isActive = true

        let name = NSTextField(labelWithString: url.lastPathComponent)
        name.font = .systemFont(ofSize: 15, weight: .semibold)
        name.lineBreakMode = .byTruncatingMiddle

        let hint = NSTextField(
            labelWithString: "Adjust the sliders. Export writes a new copy; the original is untouched."
        )
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor

        let header = NSStackView(views: [name, hint])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 2

        for slider in [brightnessSlider, contrastSlider, saturationSlider, warmthSlider] {
            slider.isContinuous = true
            slider.target = self
            slider.action = #selector(controlChanged)
            slider.translatesAutoresizingMaskIntoConstraints = false
            slider.widthAnchor.constraint(equalToConstant: 260).isActive = true
        }
        for label in [brightnessLabel, contrastLabel, saturationLabel, warmthLabel] {
            label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            label.textColor = .secondaryLabelColor
            label.alignment = .right
            label.translatesAutoresizingMaskIntoConstraints = false
            label.widthAnchor.constraint(equalToConstant: 40).isActive = true
        }

        let brightnessRow = row("Brightness", brightnessSlider, brightnessLabel)
        let contrastRow = row("Contrast", contrastSlider, contrastLabel)
        let saturationRow = row("Saturation", saturationSlider, saturationLabel)
        let warmthRow = row("Warmth", warmthSlider, warmthLabel)

        let reset = NSButton(title: "Reset", target: self, action: #selector(resetDefaults))
        reset.bezelStyle = .rounded
        reset.widthAnchor.constraint(equalToConstant: 90).isActive = true

        let apply = NSButton(title: "Apply", target: self, action: #selector(applyEdit))
        apply.bezelStyle = .rounded
        apply.keyEquivalent = "\r"
        apply.bezelColor = NSColor(srgbRed: 1.0, green: 0.42, blue: 0.18, alpha: 1.0)
        apply.widthAnchor.constraint(equalToConstant: 90).isActive = true

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttons = NSStackView(views: [reset, spacer, apply])
        buttons.orientation = .horizontal
        buttons.distribution = .fill

        let stack = NSStackView(views: [
            header, imageView, brightnessRow, contrastRow,
            saturationRow, warmthRow, buttons
        ])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])
    }

    private func row(
        _ title: String,
        _ slider: NSSlider,
        _ label: NSTextField
    ) -> NSStackView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 12)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.widthAnchor.constraint(equalToConstant: 90).isActive = true

        let row = NSStackView(views: [titleLabel, slider, label])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        return row
    }

    private func currentSpec() -> ImageAdjustSpec {
        ImageAdjustSpec(
            brightness: brightnessSlider.doubleValue / 100,
            contrast: contrastSlider.doubleValue / 100,
            saturation: saturationSlider.doubleValue / 100,
            warmth: warmthSlider.doubleValue / 100,
            format: format
        )
    }

    private func updatePreview() {
        guard let rendered = ImageAdjustEngine.render(preview, spec: currentSpec()) else {
            return
        }
        imageView.image = NSImage(
            cgImage: rendered,
            size: NSSize(width: rendered.width, height: rendered.height)
        )
        brightnessLabel.stringValue = "\(Int(brightnessSlider.doubleValue.rounded()))"
        contrastLabel.stringValue = "\(Int(contrastSlider.doubleValue.rounded()))"
        saturationLabel.stringValue = "\(Int(saturationSlider.doubleValue.rounded()))"
        warmthLabel.stringValue = "\(Int(warmthSlider.doubleValue.rounded()))"
    }

    // MARK: Actions

    @objc private func controlChanged() {
        updatePreview()
    }

    @objc private func resetDefaults() {
        brightnessSlider.doubleValue = 0
        contrastSlider.doubleValue = 0
        saturationSlider.doubleValue = 0
        warmthSlider.doubleValue = 0
        updatePreview()
    }

    @objc private func applyEdit() {
        onApply?(currentSpec())
        close()
    }
}
