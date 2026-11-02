import AppKit
import ImageEngine
import JobCore

final class CollageImageWindowController: NSWindowController {
    var onApply: ((ImageCollageSpec) -> Void)?

    private let previews: [CGImage]
    private let imageView = NSImageView()

    private let layoutControl = NSSegmentedControl(
        labels: ["Grid", "Row", "Column", "Featured"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let columnsStepper = NSStepper()
    private let columnsLabel = NSTextField(labelWithString: "2")
    private let spacingSlider = NSSlider(
        value: 16, minValue: 0, maxValue: 40, target: nil, action: nil
    )
    private let spacingLabel = NSTextField(labelWithString: "16 px")
    private let radiusSlider = NSSlider(
        value: 12, minValue: 0, maxValue: 40, target: nil, action: nil
    )
    private let radiusLabel = NSTextField(labelWithString: "12 px")
    private let colorWell = NSColorWell()
    private let formatPopup = NSPopUpButton()

    private let outputWidth = 1600

    init?(urls: [URL]) {
        guard urls.count >= 2 else { return nil }
        let previews = urls.compactMap {
            ImageConvertEngine.loadPreview(at: $0, maxPixel: 800)
        }
        guard previews.count == urls.count else { return nil }
        self.previews = previews

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 820),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Create Collage"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)

        buildUI(count: urls.count)
        updatePreview()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func buildUI(count: Int) {
        guard let window, let root = window.contentView else { return }

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.black.cgColor
        imageView.layer?.cornerRadius = 10
        imageView.layer?.masksToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.heightAnchor.constraint(equalToConstant: 440).isActive = true

        layoutControl.selectedSegment = 0
        layoutControl.target = self
        layoutControl.action = #selector(controlChanged)
        layoutControl.setContentHuggingPriority(.required, for: .horizontal)

        columnsStepper.minValue = 2
        columnsStepper.maxValue = 5
        columnsStepper.integerValue = 2
        columnsStepper.target = self
        columnsStepper.action = #selector(controlChanged)
        columnsLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        columnsLabel.textColor = .secondaryLabelColor
        columnsLabel.translatesAutoresizingMaskIntoConstraints = false
        columnsLabel.widthAnchor.constraint(equalToConstant: 20).isActive = true

        for slider in [spacingSlider, radiusSlider] {
            slider.isContinuous = true
            slider.target = self
            slider.action = #selector(controlChanged)
            slider.translatesAutoresizingMaskIntoConstraints = false
            slider.widthAnchor.constraint(equalToConstant: 220).isActive = true
        }
        for label in [spacingLabel, radiusLabel] {
            label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            label.textColor = .secondaryLabelColor
            label.translatesAutoresizingMaskIntoConstraints = false
            label.widthAnchor.constraint(equalToConstant: 52).isActive = true
        }

        colorWell.color = .white
        colorWell.target = self
        colorWell.action = #selector(controlChanged)
        colorWell.translatesAutoresizingMaskIntoConstraints = false
        colorWell.widthAnchor.constraint(equalToConstant: 44).isActive = true
        colorWell.heightAnchor.constraint(equalToConstant: 24).isActive = true

        formatPopup.addItems(withTitles: ["PNG", "JPG"])
        formatPopup.target = self
        formatPopup.action = #selector(controlChanged)

        let countLabel = NSTextField(labelWithString: "\(count) images")
        countLabel.font = .systemFont(ofSize: 11)
        countLabel.textColor = .secondaryLabelColor

        let layoutLabel = NSTextField(labelWithString: "Layout")
        let columnsTitle = NSTextField(labelWithString: "Columns")
        let spacingTitle = NSTextField(labelWithString: "Spacing")
        let radiusTitle = NSTextField(labelWithString: "Corners")
        let backgroundTitle = NSTextField(labelWithString: "Background")
        let formatTitle = NSTextField(labelWithString: "Format")
        for label in [layoutLabel, columnsTitle, spacingTitle, radiusTitle, backgroundTitle, formatTitle] {
            label.font = .systemFont(ofSize: 12)
            label.textColor = .secondaryLabelColor
            label.translatesAutoresizingMaskIntoConstraints = false
            label.widthAnchor.constraint(equalToConstant: 80).isActive = true
        }

        let layoutRow = NSStackView(views: [
            layoutLabel, layoutControl, columnsTitle, columnsLabel, columnsStepper, countLabel
        ])
        layoutRow.orientation = .horizontal
        layoutRow.alignment = .centerY
        layoutRow.spacing = 8

        let spacingRow = NSStackView(views: [spacingTitle, spacingSlider, spacingLabel])
        spacingRow.orientation = .horizontal
        spacingRow.alignment = .centerY
        spacingRow.spacing = 8

        let radiusRow = NSStackView(views: [radiusTitle, radiusSlider, radiusLabel])
        radiusRow.orientation = .horizontal
        radiusRow.alignment = .centerY
        radiusRow.spacing = 8

        let backgroundRow = NSStackView(views: [backgroundTitle, colorWell])
        backgroundRow.orientation = .horizontal
        backgroundRow.alignment = .centerY
        backgroundRow.spacing = 8

        let formatRow = NSStackView(views: [formatTitle, formatPopup])
        formatRow.orientation = .horizontal
        formatRow.alignment = .centerY
        formatRow.spacing = 8

        let reset = NSButton(title: "Reset", target: self, action: #selector(resetDefaults))
        reset.bezelStyle = .rounded
        reset.widthAnchor.constraint(equalToConstant: 90).isActive = true

        let apply = NSButton(title: "Apply", target: self, action: #selector(applyCollage))
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
            imageView, layoutRow, spacingRow, radiusRow, backgroundRow, formatRow, buttons
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
        let color = colorWell.color.usingColorSpace(.sRGB) ?? .white
        return ImageColor(
            red: Double(color.redComponent),
            green: Double(color.greenComponent),
            blue: Double(color.blueComponent),
            alpha: Double(color.alphaComponent)
        )
    }

    private func currentSpec(canvasWidth: Int, previewScale: Double = 1) -> ImageCollageSpec {
        let layouts: [ImageCollageSpec.Layout] = [.grid, .row, .column, .featured]
        let layout = layouts[max(0, min(layoutControl.selectedSegment, layouts.count - 1))]
        return ImageCollageSpec(
            layout: layout,
            columns: columnsStepper.integerValue,
            spacing: max(0, Int((spacingSlider.doubleValue * previewScale).rounded())),
            cornerRadius: max(0, Int((radiusSlider.doubleValue * previewScale).rounded())),
            background: imageColor(),
            canvasWidth: canvasWidth,
            format: formatPopup.indexOfSelectedItem == 1 ? "jpg" : "png"
        )
    }

    private func updatePreview() {
        let scale = Double(900) / Double(outputWidth)
        let spec = currentSpec(canvasWidth: 900, previewScale: scale)
        guard let rendered = ImageCollageEngine.render(images: previews, spec: spec) else {
            return
        }
        imageView.image = NSImage(
            cgImage: rendered,
            size: NSSize(width: rendered.width, height: rendered.height)
        )
    }

    // MARK: Actions

    @objc private func controlChanged() {
        columnsLabel.stringValue = "\(columnsStepper.integerValue)"
        spacingLabel.stringValue = "\(Int(spacingSlider.doubleValue.rounded())) px"
        radiusLabel.stringValue = "\(Int(radiusSlider.doubleValue.rounded())) px"
        columnsStepper.isEnabled = layoutControl.selectedSegment == 0
        updatePreview()
    }

    @objc private func resetDefaults() {
        layoutControl.selectedSegment = 0
        columnsStepper.integerValue = 2
        spacingSlider.doubleValue = 16
        radiusSlider.doubleValue = 12
        colorWell.color = .white
        formatPopup.selectItem(at: 0)
        controlChanged()
    }

    @objc private func applyCollage() {
        onApply?(currentSpec(canvasWidth: outputWidth))
        close()
    }
}
