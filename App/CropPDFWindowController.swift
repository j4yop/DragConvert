import AppKit
import PDFKit
import JobCore

final class CropPDFWindowController: NSWindowController {
    var onApply: ((PDFCropSpec) -> Void)?

    private let pageCount: Int
    private let pageSize: CGSize
    private let imageSize: CGSize
    private let canvas = CropCanvas()
    private let widthField = NSTextField(labelWithString: "0")
    private let heightField = NSTextField(labelWithString: "0")
    private let aspectControl = NSSegmentedControl(
        labels: ["Free", "1:1", "16:9", "9:16", "4:3", "3:4"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )

    init?(url: URL) {
        guard let document = PDFDocument(url: url),
              let page = document.page(at: 0) else { return nil }

        self.pageCount = document.pageCount
        let bounds = page.bounds(for: .mediaBox)
        self.pageSize = bounds.size

        let maxWidth: CGFloat = 1200
        let scale = min(2.0, maxWidth / max(1, bounds.width))
        let pixelWidth = max(1, Int(bounds.width * scale))
        let pixelHeight = max(1, Int(bounds.height * scale))
        self.imageSize = CGSize(width: pixelWidth, height: pixelHeight)

        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }

        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
        guard let image = context.makeImage() else { return nil }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 700),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Crop PDF"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)

        canvas.image = image
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
            field.translatesAutoresizingMaskIntoConstraints = false
            field.widthAnchor.constraint(equalToConstant: 74).isActive = true
        }

        let wLabel = NSTextField(labelWithString: "W")
        let hLabel = NSTextField(labelWithString: "H")
        let ptLabel = NSTextField(labelWithString: "pt")
        for label in [wLabel, hLabel, ptLabel] {
            label.font = .systemFont(ofSize: 12)
            label.textColor = .secondaryLabelColor
        }

        let sizeRow = NSStackView(views: [wLabel, widthField, hLabel, heightField, ptLabel])
        sizeRow.orientation = .horizontal
        sizeRow.alignment = .centerY
        sizeRow.spacing = 8

        let hint = NSTextField(
            wrappingLabelWithString: "The same crop is applied to all \(pageCount) pages. The original PDF is untouched."
        )
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .tertiaryLabelColor
        hint.preferredMaxLayoutWidth = 440

        let reset = NSButton(title: "Reset", target: self, action: #selector(resetCrop))
        reset.bezelStyle = .rounded
        reset.widthAnchor.constraint(equalToConstant: 90).isActive = true

        let apply = NSButton(title: "Apply", target: self, action: #selector(applyCrop))
        apply.bezelStyle = .rounded
        apply.keyEquivalent = "\r"
        apply.bezelColor = NSColor(srgbRed: 1.0, green: 0.42, blue: 0.18, alpha: 1.0)
        apply.widthAnchor.constraint(equalToConstant: 90).isActive = true

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttons = NSStackView(views: [reset, spacer, apply])
        buttons.orientation = .horizontal
        buttons.distribution = .fill

        let stack = NSStackView(views: [canvas, aspectRow, sizeRow, hint, buttons])
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
            canvas.heightAnchor.constraint(equalToConstant: 480)
        ])
    }

    private func updateFields() {
        let pixel = canvas.pixelRect()
        guard imageSize.width > 0, imageSize.height > 0 else { return }
        let width = pixel.width / imageSize.width * pageSize.width
        let height = pixel.height / imageSize.height * pageSize.height
        widthField.stringValue = "\(Int(width.rounded()))"
        heightField.stringValue = "\(Int(height.rounded()))"
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
        let pixel = canvas.pixelRect()
        guard imageSize.width > 0, imageSize.height > 0,
              pixel.width >= 1, pixel.height >= 1 else { return }

        let spec = PDFCropSpec(
            x: Double(pixel.minX / imageSize.width),
            y: Double(pixel.minY / imageSize.height),
            width: Double(pixel.width / imageSize.width),
            height: Double(pixel.height / imageSize.height)
        )
        onApply?(spec)
        close()
    }
}
