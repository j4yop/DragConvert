import AppKit
import ImageEngine
import JobCore

final class ImageAdjustWindowController: NSWindowController {
    enum Mode {
        case resize, rotate

        var title: String {
            switch self {
            case .resize: return "Resize Image"
            case .rotate: return "Rotate Image"
            }
        }
    }

    var onApply: ((ImageEditSpec) -> Void)?

    private let mode: Mode
    private let original: CGImage
    private let previewBase: CGImage
    private let format: String

    private let imageView = NSImageView()
    private let widthField = NSTextField()
    private let heightField = NSTextField()
    private let lockCheckbox = NSButton(
        checkboxWithTitle: "Lock aspect",
        target: nil,
        action: nil
    )

    private var quarterTurns = 0
    private var flipHorizontal = false
    private var flipVertical = false

    init?(url: URL, mode: Mode) {
        guard let loaded = ImageConvertEngine.loadImage(at: url) else { return nil }
        self.mode = mode
        self.original = loaded
        let previewWidth = min(1000, loaded.width)
        let previewHeight = max(
            1,
            Int(Double(loaded.height) * Double(previewWidth) / Double(loaded.width))
        )
        self.previewBase = ImageEditEngine.resize(
            loaded,
            width: previewWidth,
            height: previewHeight
        ) ?? loaded

        let ext = url.pathExtension.lowercased()
        self.format = ["jpg", "jpeg", "png", "heic", "tiff"].contains(ext) ? ext : "jpg"

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 700),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = mode.title
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)

        buildUI()
        resetAll()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    // MARK: UI

    private func buildUI() {
        guard let window, let root = window.contentView else { return }

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.black.cgColor
        imageView.layer?.cornerRadius = 10
        imageView.layer?.masksToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.heightAnchor.constraint(equalToConstant: 360).isActive = true

        for field in [widthField, heightField] {
            field.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            field.alignment = .right
            field.isBezeled = true
            field.isEditable = true
            field.drawsBackground = true
            field.target = self
            field.action = #selector(sizeFieldChanged(_:))
            (field.cell as? NSTextFieldCell)?.sendsActionOnEndEditing = true
            let formatter = NumberFormatter()
            formatter.numberStyle = .none
            formatter.minimum = 1
            formatter.maximum = 100_000
            formatter.allowsFloats = false
            field.formatter = formatter
            field.translatesAutoresizingMaskIntoConstraints = false
            field.widthAnchor.constraint(equalToConstant: 84).isActive = true
        }

        lockCheckbox.target = self
        lockCheckbox.action = #selector(lockChanged)
        lockCheckbox.state = .on
        lockCheckbox.font = .systemFont(ofSize: 12)

        let wLabel = NSTextField(labelWithString: "W")
        let hLabel = NSTextField(labelWithString: "H")
        let pxLabel = NSTextField(labelWithString: "px")
        for label in [wLabel, hLabel, pxLabel] {
            label.font = .systemFont(ofSize: 12)
            label.textColor = .secondaryLabelColor
        }

        let sizeRow = NSStackView(views: [
            wLabel, widthField, hLabel, heightField, pxLabel, lockCheckbox
        ])
        sizeRow.orientation = .horizontal
        sizeRow.alignment = .centerY
        sizeRow.spacing = 8

        let rotateLeft = NSButton(title: "↺  90°", target: self, action: #selector(rotateLeftTapped))
        let rotateRight = NSButton(title: "↻  90°", target: self, action: #selector(rotateRightTapped))
        let flipH = NSButton(title: "Flip H", target: self, action: #selector(flipHTapped))
        let flipV = NSButton(title: "Flip V", target: self, action: #selector(flipVTapped))
        for button in [rotateLeft, rotateRight, flipH, flipV] {
            button.bezelStyle = .rounded
            button.font = .systemFont(ofSize: 12)
        }

        let transformRow = NSStackView(views: [rotateLeft, rotateRight, flipH, flipV])
        transformRow.orientation = .horizontal
        transformRow.spacing = 8

        let reset = NSButton(title: "Reset", target: self, action: #selector(resetAll))
        reset.bezelStyle = .rounded
        reset.widthAnchor.constraint(equalToConstant: 90).isActive = true

        let apply = NSButton(title: "Apply", target: self, action: #selector(applyEdit))
        apply.bezelStyle = .rounded
        apply.keyEquivalent = "\r"
        apply.bezelColor = NSColor(srgbRed: 1.0, green: 0.42, blue: 0.18, alpha: 1.0)
        apply.widthAnchor.constraint(equalToConstant: 90).isActive = true

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttonRow = NSStackView(views: [reset, spacer, apply])
        buttonRow.orientation = .horizontal
        buttonRow.distribution = .fill

        let hint = NSTextField(labelWithString: "Rotation is applied before resizing.")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .tertiaryLabelColor

        let stack = NSStackView(views: [
            imageView, sizeRow, transformRow, hint, buttonRow
        ])
        stack.orientation = .vertical
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
        stack.setCustomSpacing(20, after: transformRow)
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])
    }

    // MARK: State

    private var rotatedWidth: Int {
        quarterTurns % 2 == 0 ? original.width : original.height
    }

    private var rotatedHeight: Int {
        quarterTurns % 2 == 0 ? original.height : original.width
    }

    private var rotatedAspect: Double {
        Double(rotatedHeight) / Double(max(1, rotatedWidth))
    }

    @objc private func resetAll() {
        quarterTurns = 0
        flipHorizontal = false
        flipVertical = false
        widthField.stringValue = "\(original.width)"
        heightField.stringValue = "\(original.height)"
        updatePreview()
    }

    private func updatePreview() {
        let rendered = ImageEditEngine.render(
            previewBase,
            quarterTurns: quarterTurns,
            flipHorizontal: flipHorizontal,
            flipVertical: flipVertical
        ) ?? previewBase
        imageView.image = NSImage(
            cgImage: rendered,
            size: NSSize(width: rendered.width, height: rendered.height)
        )
    }

    @objc private func rotateLeftTapped() {
        quarterTurns = (quarterTurns + 3) % 4
        swapSizeFieldsIfNeeded()
        updatePreview()
    }

    @objc private func rotateRightTapped() {
        quarterTurns = (quarterTurns + 1) % 4
        swapSizeFieldsIfNeeded()
        updatePreview()
    }

    @objc private func flipHTapped() {
        flipHorizontal.toggle()
        updatePreview()
    }

    @objc private func flipVTapped() {
        flipVertical.toggle()
        updatePreview()
    }

    @objc private func lockChanged() {
        if lockCheckbox.state == .on {
            let width = Int(widthField.stringValue) ?? rotatedWidth
            let height = max(1, Int((Double(width) * rotatedAspect).rounded()))
            heightField.stringValue = "\(height)"
        }
    }

    @objc private func sizeFieldChanged(_ sender: NSTextField) {
        guard lockCheckbox.state == .on else { return }
        if sender === widthField {
            let width = Int(widthField.stringValue) ?? rotatedWidth
            let height = max(1, Int((Double(width) * rotatedAspect).rounded()))
            heightField.stringValue = "\(height)"
        } else {
            let height = Int(heightField.stringValue) ?? rotatedHeight
            let width = max(1, Int((Double(height) / max(0.0001, rotatedAspect)).rounded()))
            widthField.stringValue = "\(width)"
        }
    }

    private func swapSizeFieldsIfNeeded() {
        guard lockCheckbox.state == .on else { return }
        let width = widthField.stringValue
        widthField.stringValue = heightField.stringValue
        heightField.stringValue = width
    }

    @objc private func applyEdit() {
        let width = Int(widthField.stringValue) ?? rotatedWidth
        let height = Int(heightField.stringValue) ?? rotatedHeight
        let sizeChanged = width != rotatedWidth || height != rotatedHeight
        let transformChanged = quarterTurns % 4 != 0 || flipHorizontal || flipVertical
        let suffix: String
        if sizeChanged && transformChanged {
            suffix = "Edited"
        } else if sizeChanged {
            suffix = "Resized"
        } else {
            suffix = "Rotated"
        }

        let spec = ImageEditSpec(
            width: max(1, width),
            height: max(1, height),
            quarterTurns: quarterTurns,
            flipHorizontal: flipHorizontal,
            flipVertical: flipVertical,
            format: format,
            suffix: suffix
        )
        onApply?(spec)
        close()
    }
}
