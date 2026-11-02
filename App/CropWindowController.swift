import AppKit
import ImageEngine

final class CropWindowController: NSWindowController {
    var onApply: ((CGRect) -> Void)?

    private let canvas = CropCanvas()
    private let widthField = NSTextField(labelWithString: "0")
    private let heightField = NSTextField(labelWithString: "0")
    private let aspectControl = NSSegmentedControl(
        labels: ["Free", "1:1", "16:9", "9:16", "4:3", "3:4"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let resetButton = NSButton(title: "Reset", target: nil, action: nil)
    private let applyButton = NSButton(title: "Apply", target: nil, action: nil)

    init?(url: URL) {
        guard let sourceSize = ImageConvertEngine.imageSize(at: url),
              let preview = ImageConvertEngine.loadPreview(at: url, maxPixel: 1800)
        else { return nil }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 680),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Crop Image"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)

        canvas.sourceSize = sourceSize
        canvas.image = preview
        canvas.onCropChanged = { [weak self] _ in self?.updateFields() }
        buildUI()
        updateFields()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func buildUI() {
        guard let window, let root = window.contentView else { return }

        canvas.translatesAutoresizingMaskIntoConstraints = false
        canvas.wantsLayer = true
        canvas.layer?.cornerRadius = 10
        canvas.layer?.masksToBounds = true
        canvas.layer?.backgroundColor = NSColor.black.cgColor

        let aspectLabel = NSTextField(labelWithString: "Aspect ratio")
        aspectLabel.font = .systemFont(ofSize: 12)
        aspectLabel.textColor = .secondaryLabelColor

        aspectControl.target = self
        aspectControl.action = #selector(aspectChanged(_:))
        aspectControl.selectedSegment = 0
        aspectControl.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let aspectRow = NSStackView(views: [aspectLabel, aspectControl])
        aspectRow.orientation = .horizontal
        aspectRow.alignment = .centerY
        aspectRow.spacing = 12
        aspectRow.distribution = .fill

        for field in [widthField, heightField] {
            field.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            field.alignment = .right
            field.isSelectable = true
            field.isEditable = true
            field.isBezeled = true
            field.drawsBackground = true
            field.target = self
            field.action = #selector(sizeChanged(_:))
            (field.cell as? NSTextFieldCell)?.sendsActionOnEndEditing = true
            let formatter = NumberFormatter()
            formatter.numberStyle = .none
            formatter.minimum = 1
            formatter.maximum = 100_000
            formatter.allowsFloats = false
            field.formatter = formatter
            field.translatesAutoresizingMaskIntoConstraints = false
            field.widthAnchor.constraint(equalToConstant: 80).isActive = true
        }

        let wLabel = NSTextField(labelWithString: "W")
        let hLabel = NSTextField(labelWithString: "H")
        let pxLabel = NSTextField(labelWithString: "px")
        for label in [wLabel, hLabel, pxLabel] {
            label.font = .systemFont(ofSize: 12)
            label.textColor = .secondaryLabelColor
        }

        let sizeRow = NSStackView(views: [wLabel, widthField, hLabel, heightField, pxLabel])
        sizeRow.orientation = .horizontal
        sizeRow.alignment = .centerY
        sizeRow.spacing = 8

        resetButton.target = self
        resetButton.action = #selector(resetCrop)
        resetButton.bezelStyle = .rounded
        resetButton.widthAnchor.constraint(equalToConstant: 90).isActive = true

        applyButton.target = self
        applyButton.action = #selector(applyCrop)
        applyButton.bezelStyle = .rounded
        applyButton.keyEquivalent = "\r"
        applyButton.bezelColor = NSColor(
            srgbRed: 1.0, green: 0.42, blue: 0.18, alpha: 1.0
        )
        applyButton.widthAnchor.constraint(equalToConstant: 90).isActive = true

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttonsRow = NSStackView(views: [resetButton, spacer, applyButton])
        buttonsRow.orientation = .horizontal
        buttonsRow.spacing = 12
        buttonsRow.distribution = .fill

        let hint = NSTextField(
            labelWithString: "Drag any of the eight handles, or type an exact size."
        )
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .tertiaryLabelColor

        let stack = NSStackView(views: [canvas, aspectRow, sizeRow, hint, buttonsRow])
        stack.orientation = .vertical
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            canvas.heightAnchor.constraint(equalToConstant: 500)
        ])
    }

    private func updateFields() {
        let rect = canvas.sourcePixelRect()
        widthField.stringValue = "\(Int(rect.width))"
        heightField.stringValue = "\(Int(rect.height))"
    }

    @objc private func sizeChanged(_ sender: NSTextField) {
        let current = canvas.sourcePixelRect()
        var width = Int(widthField.stringValue) ?? Int(current.width)
        var height = Int(heightField.stringValue) ?? Int(current.height)

        if let aspect = canvas.aspect {
            if sender === widthField {
                height = max(1, Int((Double(width) / aspect).rounded()))
            } else {
                width = max(1, Int((Double(height) * aspect).rounded()))
            }
        }

        canvas.setCropSize(
            widthPixels: max(1, width),
            heightPixels: max(1, height)
        )
        updateFields()
    }

    @objc private func aspectChanged(_ sender: NSSegmentedControl) {
        let ratios: [CGFloat?] = [nil, 1, 16.0 / 9.0, 9.0 / 16.0, 4.0 / 3.0, 3.0 / 4.0]
        canvas.aspect = ratios[max(0, min(sender.selectedSegment, ratios.count - 1))]
    }

    @objc private func resetCrop() {
        aspectControl.selectedSegment = 0
        canvas.aspect = nil
        canvas.reset()
    }

    @objc private func applyCrop() {
        let rect = canvas.sourcePixelRect()
        guard rect.width >= 1, rect.height >= 1 else { return }
        onApply?(rect)
        close()
    }
}
