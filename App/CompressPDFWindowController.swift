import AppKit
import PDFKit
import JobCore

final class CompressPDFWindowController: NSWindowController {
    var onApply: ((PDFCompressSpec) -> Void)?

    private let pageCount: Int
    private let originalBytes: Int
    private let modeControl = NSSegmentedControl(
        labels: ["Balanced", "Target size"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let targetField = NSTextField()
    private let targetRow = NSStackView()
    private let hint = NSTextField(wrappingLabelWithString: "")

    init(url: URL) {
        let document = PDFDocument(url: url)
        self.pageCount = document?.pageCount ?? 0
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        self.originalBytes = (attributes?[.size] as? NSNumber)?.intValue ?? 0

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Compress PDF"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)

        buildUI(url: url)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func buildUI(url: URL) {
        guard let window, let root = window.contentView else { return }

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        let sizeText = originalBytes > 0
            ? formatter.string(fromByteCount: Int64(originalBytes))
            : "unknown size"

        let name = NSTextField(labelWithString: url.lastPathComponent)
        name.font = .systemFont(ofSize: 15, weight: .semibold)
        name.lineBreakMode = .byTruncatingMiddle

        let info = NSTextField(
            labelWithString: "\(pageCount) pages · \(sizeText) · text is kept in Balanced mode"
        )
        info.font = .systemFont(ofSize: 11)
        info.textColor = .secondaryLabelColor

        let header = NSStackView(views: [name, info])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 2

        modeControl.target = self
        modeControl.action = #selector(modeChanged(_:))
        modeControl.selectedSegment = 0

        let targetLabel = NSTextField(labelWithString: "Target")
        targetLabel.font = .systemFont(ofSize: 12)
        targetLabel.textColor = .secondaryLabelColor

        targetField.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        targetField.alignment = .right
        targetField.isBezeled = true
        targetField.translatesAutoresizingMaskIntoConstraints = false
        targetField.widthAnchor.constraint(equalToConstant: 90).isActive = true
        let number = NumberFormatter()
        number.numberStyle = .none
        number.minimum = 10
        number.maximum = 1_000_000
        number.allowsFloats = false
        targetField.formatter = number

        let kbLabel = NSTextField(labelWithString: "KB")
        kbLabel.font = .systemFont(ofSize: 12)
        kbLabel.textColor = .secondaryLabelColor

        targetRow.setViews([targetLabel, targetField, kbLabel], in: .leading)
        targetRow.orientation = .horizontal
        targetRow.alignment = .centerY
        targetRow.spacing = 8

        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .tertiaryLabelColor
        hint.preferredMaxLayoutWidth = 460

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
        let buttons = NSStackView(views: [reset, spacer, apply])
        buttons.orientation = .horizontal
        buttons.distribution = .fill

        let stack = NSStackView(views: [header, modeControl, hint, targetRow, buttons])
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

        resetDefaults()
    }

    @objc private func modeChanged(_ sender: NSSegmentedControl) {
        let targetMode = sender.selectedSegment == 1
        targetField.isEnabled = targetMode
        hint.stringValue = targetMode
            ? "Rasterises pages to hit the target. Text will no longer be selectable, but the page images stay readable."
            : "Recompresses images and keeps text selectable. If the result would be larger, the original is copied unchanged."
    }

    @objc private func resetDefaults() {
        modeControl.selectedSegment = 0
        let halfKB = originalBytes > 0 ? max(50, (originalBytes / 1024) / 2) : 500
        targetField.stringValue = "\(halfKB)"
        modeChanged(modeControl)
    }

    @objc private func applyCompress() {
        let targetMode = modeControl.selectedSegment == 1
        let spec = PDFCompressSpec(
            mode: targetMode ? .targetSize : .balanced,
            targetBytes: max(10, (Int(targetField.stringValue) ?? 500)) * 1024
        )
        onApply?(spec)
        close()
    }
}
