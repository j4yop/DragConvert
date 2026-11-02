import AppKit
import JobCore

final class CompressWindowController: NSWindowController {
    var onApply: ((CompressSpec) -> Void)?

    private let format: String
    private let originalBytes: Int

    private let infoLabel = NSTextField(labelWithString: "")
    private let modeControl = NSSegmentedControl(
        labels: ["Target size", "Quality"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let targetField = NSTextField()
    private let allowResize = NSButton(
        checkboxWithTitle: "Allow resizing if needed",
        target: nil,
        action: nil
    )
    private let qualitySlider = NSSlider(
        value: 75, minValue: 10, maxValue: 100, target: nil, action: nil
    )
    private let qualityValue = NSTextField(labelWithString: "75%")
    private let targetRow = NSStackView()
    private let qualityRow = NSStackView()

    init(url: URL) {
        let ext = url.pathExtension.lowercased()
        self.format = ["jpg", "jpeg", "png", "heic", "tiff"].contains(ext) ? ext : "jpg"
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        self.originalBytes = (attributes?[.size] as? NSNumber)?.intValue ?? 0

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Compress Image"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)

        buildUI()
        applyDefaults()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func buildUI() {
        guard let window, let root = window.contentView else { return }

        infoLabel.font = .systemFont(ofSize: 12)
        infoLabel.textColor = .secondaryLabelColor

        modeControl.target = self
        modeControl.action = #selector(modeChanged(_:))
        modeControl.selectedSegment = 0

        let targetLabel = NSTextField(labelWithString: "Target")
        let kbLabel = NSTextField(labelWithString: "KB")
        for label in [targetLabel, kbLabel] {
            label.font = .systemFont(ofSize: 12)
            label.textColor = .secondaryLabelColor
        }

        targetField.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        targetField.alignment = .right
        targetField.isBezeled = true
        targetField.translatesAutoresizingMaskIntoConstraints = false
        targetField.widthAnchor.constraint(equalToConstant: 90).isActive = true
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 1
        formatter.maximum = 1_000_000
        formatter.allowsFloats = false
        targetField.formatter = formatter

        allowResize.state = .on
        allowResize.font = .systemFont(ofSize: 12)

        targetRow.setViews([targetLabel, targetField, kbLabel, allowResize], in: .leading)
        targetRow.orientation = .horizontal
        targetRow.alignment = .centerY
        targetRow.spacing = 8

        let qualityLabel = NSTextField(labelWithString: "Quality")
        qualityLabel.font = .systemFont(ofSize: 12)
        qualityLabel.textColor = .secondaryLabelColor

        qualitySlider.target = self
        qualitySlider.action = #selector(qualityChanged(_:))
        qualitySlider.translatesAutoresizingMaskIntoConstraints = false
        qualitySlider.widthAnchor.constraint(equalToConstant: 220).isActive = true

        qualityValue.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        qualityValue.alignment = .right
        qualityValue.translatesAutoresizingMaskIntoConstraints = false
        qualityValue.widthAnchor.constraint(equalToConstant: 44).isActive = true

        qualityRow.setViews([qualityLabel, qualitySlider, qualityValue], in: .leading)
        qualityRow.orientation = .horizontal
        qualityRow.alignment = .centerY
        qualityRow.spacing = 8

        let hint = NSTextField(
            wrappingLabelWithString: "If the file is already smaller than the target, it is copied unchanged. Resizing is only used when quality alone cannot reach the target."
        )
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .tertiaryLabelColor
        hint.preferredMaxLayoutWidth = 440

        let reset = NSButton(title: "Reset", target: self, action: #selector(resetDefaults))
        reset.bezelStyle = .rounded
        reset.widthAnchor.constraint(equalToConstant: 90).isActive = true

        let apply = NSButton(title: "Apply", target: self, action: #selector(applyCompress))
        apply.bezelStyle = .rounded
        apply.keyEquivalent = "\r"
        apply.bezelColor = NSColor(srgbRed: 1.0, green: 0.42, blue: 0.18, alpha: 1.0)
        apply.widthAnchor.constraint(equalToConstant: 90).isActive = true

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttonRow = NSStackView(views: [reset, spacer, apply])
        buttonRow.orientation = .horizontal
        buttonRow.distribution = .fill

        let stack = NSStackView(views: [
            infoLabel, modeControl, targetRow, qualityRow, hint, buttonRow
        ])
        stack.orientation = .vertical
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor)
        ])
    }

    private func applyDefaults() {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        infoLabel.stringValue = originalBytes > 0
            ? "Original · \(formatter.string(fromByteCount: Int64(originalBytes)))"
            : "Original size unknown"

        let halfKB = originalBytes > 0 ? max(50, (originalBytes / 1024) / 2) : 500
        targetField.stringValue = "\(halfKB)"
        modeChanged(modeControl)
    }

    @objc private func modeChanged(_ sender: NSSegmentedControl) {
        let targetMode = sender.selectedSegment == 0
        targetField.isEnabled = targetMode
        allowResize.isEnabled = targetMode
        qualitySlider.isEnabled = !targetMode
        qualityValue.textColor = targetMode ? .tertiaryLabelColor : .labelColor
    }

    @objc private func qualityChanged(_ sender: NSSlider) {
        qualityValue.stringValue = "\(Int(sender.doubleValue.rounded()))%"
    }

    @objc private func resetDefaults() {
        modeControl.selectedSegment = 0
        qualitySlider.doubleValue = 75
        qualityValue.stringValue = "75%"
        applyDefaults()
    }

    @objc private func applyCompress() {
        let targetKB = Int(targetField.stringValue) ?? 500
        let spec = CompressSpec(
            mode: modeControl.selectedSegment == 0 ? .targetSize : .quality,
            targetBytes: max(1, targetKB * 1024),
            quality: qualitySlider.doubleValue / 100,
            allowResize: allowResize.state == .on,
            format: format
        )
        onApply?(spec)
        close()
    }
}
