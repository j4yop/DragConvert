import AppKit
import UniformTypeIdentifiers
import ImageEngine
import JobCore

final class FrameImageWindowController: NSWindowController {
    var onApply: ((ImageFrameSpec) -> Void)?

    private let preview: CGImage
    private let previewScale: Double
    private let imageView = NSImageView()

    private let paddingSlider = NSSlider(
        value: 12, minValue: 0, maxValue: 30, target: nil, action: nil
    )
    private let paddingLabel = NSTextField(labelWithString: "12%")
    private let radiusSlider = NSSlider(
        value: 24, minValue: 0, maxValue: 80, target: nil, action: nil
    )
    private let radiusLabel = NSTextField(labelWithString: "24 px")
    private let shadowCheckbox = NSButton(
        checkboxWithTitle: "Shadow", target: nil, action: nil
    )
    private let blurCheckbox = NSButton(
        checkboxWithTitle: "Blur background", target: nil, action: nil
    )
    private let backgroundControl = NSSegmentedControl(
        labels: ["Colour", "Image"], trackingMode: .selectOne, target: nil, action: nil
    )
    private let colorWell = NSColorWell()
    private let chooseButton = NSButton(title: "Choose Image…", target: nil, action: nil)
    private let backgroundLabel = NSTextField(labelWithString: "No image chosen")
    private let formatPopup = NSPopUpButton()

    private var backgroundURL: URL?
    private var backgroundPreview: CGImage?

    init?(url: URL) {
        guard let preview = ImageConvertEngine.loadPreview(at: url, maxPixel: 1000),
              let fullSize = ImageConvertEngine.imageSize(at: url),
              fullSize.width > 0 else { return nil }

        self.preview = preview
        self.previewScale = Double(preview.width) / Double(fullSize.width)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 780),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Add Background"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)

        buildUI()
        updateBackgroundControls()
        updatePreview()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func buildUI() {
        guard let window, let root = window.contentView else { return }

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.black.cgColor
        imageView.layer?.cornerRadius = 10
        imageView.layer?.masksToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.heightAnchor.constraint(equalToConstant: 400).isActive = true

        paddingSlider.isContinuous = true
        paddingSlider.target = self
        paddingSlider.action = #selector(controlChanged)
        paddingSlider.translatesAutoresizingMaskIntoConstraints = false
        paddingSlider.widthAnchor.constraint(equalToConstant: 240).isActive = true

        radiusSlider.isContinuous = true
        radiusSlider.target = self
        radiusSlider.action = #selector(controlChanged)
        radiusSlider.translatesAutoresizingMaskIntoConstraints = false
        radiusSlider.widthAnchor.constraint(equalToConstant: 240).isActive = true

        for label in [paddingLabel, radiusLabel] {
            label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            label.textColor = .secondaryLabelColor
            label.translatesAutoresizingMaskIntoConstraints = false
            label.widthAnchor.constraint(equalToConstant: 52).isActive = true
        }

        shadowCheckbox.state = .on
        shadowCheckbox.target = self
        shadowCheckbox.action = #selector(controlChanged)
        blurCheckbox.state = .off
        blurCheckbox.target = self
        blurCheckbox.action = #selector(controlChanged)

        backgroundControl.selectedSegment = 0
        backgroundControl.target = self
        backgroundControl.action = #selector(backgroundChanged)

        colorWell.color = NSColor(
            srgbRed: 0.96, green: 0.94, blue: 0.90, alpha: 1
        )
        colorWell.target = self
        colorWell.action = #selector(controlChanged)
        colorWell.translatesAutoresizingMaskIntoConstraints = false
        colorWell.widthAnchor.constraint(equalToConstant: 44).isActive = true
        colorWell.heightAnchor.constraint(equalToConstant: 24).isActive = true

        chooseButton.bezelStyle = .rounded
        chooseButton.target = self
        chooseButton.action = #selector(chooseBackground)

        backgroundLabel.font = .systemFont(ofSize: 11)
        backgroundLabel.textColor = .secondaryLabelColor
        backgroundLabel.lineBreakMode = .byTruncatingMiddle

        formatPopup.addItems(withTitles: ["PNG", "JPG"])
        formatPopup.target = self
        formatPopup.action = #selector(controlChanged)

        let paddingLabelFixed = NSTextField(labelWithString: "Padding")
        let radiusLabelFixed = NSTextField(labelWithString: "Corners")
        for label in [paddingLabelFixed, radiusLabelFixed] {
            label.font = .systemFont(ofSize: 12)
            label.textColor = .secondaryLabelColor
            label.translatesAutoresizingMaskIntoConstraints = false
            label.widthAnchor.constraint(equalToConstant: 64).isActive = true
        }

        let paddingRow = NSStackView(views: [
            paddingLabelFixed, paddingSlider, paddingLabel
        ])
        paddingRow.orientation = .horizontal
        paddingRow.alignment = .centerY
        paddingRow.spacing = 10

        let radiusRow = NSStackView(views: [
            radiusLabelFixed, radiusSlider, radiusLabel
        ])
        radiusRow.orientation = .horizontal
        radiusRow.alignment = .centerY
        radiusRow.spacing = 10

        let togglesRow = NSStackView(views: [shadowCheckbox, blurCheckbox])
        togglesRow.orientation = .horizontal
        togglesRow.spacing = 14

        let backgroundRow = NSStackView(views: [
            backgroundControl, colorWell, chooseButton, backgroundLabel
        ])
        backgroundRow.orientation = .horizontal
        backgroundRow.alignment = .centerY
        backgroundRow.spacing = 10

        let formatLabel = NSTextField(labelWithString: "Format")
        formatLabel.font = .systemFont(ofSize: 12)
        formatLabel.textColor = .secondaryLabelColor
        let formatRow = NSStackView(views: [formatLabel, formatPopup])
        formatRow.orientation = .horizontal
        formatRow.alignment = .centerY
        formatRow.spacing = 10

        let reset = NSButton(title: "Reset", target: self, action: #selector(resetDefaults))
        reset.bezelStyle = .rounded
        reset.widthAnchor.constraint(equalToConstant: 90).isActive = true

        let apply = NSButton(title: "Apply", target: self, action: #selector(applyFrame))
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
            imageView, paddingRow, radiusRow, togglesRow, backgroundRow, formatRow, buttons
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

    private func imageColor() -> ImageColor {
        let color = (colorWell.color.usingColorSpace(.sRGB) ?? .white)
        return ImageColor(
            red: Double(color.redComponent),
            green: Double(color.greenComponent),
            blue: Double(color.blueComponent),
            alpha: Double(color.alphaComponent)
        )
    }

    private func currentSpec() -> ImageFrameSpec {
        let background: ImageFrameSpec.Background
        if backgroundControl.selectedSegment == 1, let backgroundURL {
            background = .image(backgroundURL)
        } else {
            background = .color(imageColor())
        }
        return ImageFrameSpec(
            paddingPercent: paddingSlider.doubleValue / 100,
            cornerRadius: Int(radiusSlider.doubleValue.rounded()),
            shadow: shadowCheckbox.state == .on,
            blurBackground: blurCheckbox.state == .on,
            background: background,
            format: formatPopup.indexOfSelectedItem == 1 ? "jpg" : "png"
        )
    }

    private func updateBackgroundControls() {
        let imageMode = backgroundControl.selectedSegment == 1
        colorWell.isEnabled = !imageMode
        chooseButton.isEnabled = imageMode
        blurCheckbox.isEnabled = imageMode && backgroundPreview != nil
    }

    private func updatePreview() {
        var spec = currentSpec()
        spec.cornerRadius = Int((Double(spec.cornerRadius) * previewScale).rounded())

        let background: CGImage?
        if backgroundControl.selectedSegment == 1 {
            background = backgroundPreview
        } else {
            background = nil
        }

        guard let rendered = ImageFrameEngine.render(
            foreground: preview,
            background: background,
            spec: spec
        ) else { return }

        imageView.image = NSImage(
            cgImage: rendered,
            size: NSSize(width: rendered.width, height: rendered.height)
        )
    }

    // MARK: Actions

    @objc private func controlChanged() {
        paddingLabel.stringValue = "\(Int(paddingSlider.doubleValue.rounded()))%"
        radiusLabel.stringValue = "\(Int(radiusSlider.doubleValue.rounded())) px"
        updatePreview()
    }

    @objc private func backgroundChanged() {
        updateBackgroundControls()
        updatePreview()
    }

    @objc private func chooseBackground() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Use Image"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let preview = ImageConvertEngine.loadPreview(at: url, maxPixel: 1000) else {
            NSSound.beep()
            return
        }
        backgroundURL = url
        backgroundPreview = preview
        backgroundLabel.stringValue = url.lastPathComponent
        backgroundControl.selectedSegment = 1
        updateBackgroundControls()
        updatePreview()
    }

    @objc private func resetDefaults() {
        paddingSlider.doubleValue = 12
        radiusSlider.doubleValue = 24
        shadowCheckbox.state = .on
        blurCheckbox.state = .off
        backgroundControl.selectedSegment = 0
        formatPopup.selectItem(at: 0)
        paddingLabel.stringValue = "12%"
        radiusLabel.stringValue = "24 px"
        updateBackgroundControls()
        updatePreview()
    }

    @objc private func applyFrame() {
        if backgroundControl.selectedSegment == 1, backgroundURL == nil {
            NSSound.beep()
            return
        }
        onApply?(currentSpec())
        close()
    }
}
