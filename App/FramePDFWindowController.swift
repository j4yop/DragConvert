import AppKit
import PDFKit
import UniformTypeIdentifiers
import PDFEngine
import ImageEngine
import JobCore

final class FramePDFWindowController: NSWindowController {
    var onApply: ((PDFFrameSpec) -> Void)?

    private let preview: CGImage
    private let pageCount: Int
    private let imageView = NSImageView()

    private let paddingSlider = NSSlider(
        value: 12, minValue: 0, maxValue: 25, target: nil, action: nil
    )
    private let paddingLabel = NSTextField(labelWithString: "12%")
    private let shadowCheckbox = NSButton(
        checkboxWithTitle: "Shadow", target: nil, action: nil
    )
    private let backgroundControl = NSSegmentedControl(
        labels: ["Colour", "Image"], trackingMode: .selectOne, target: nil, action: nil
    )
    private let colorWell = NSColorWell()
    private let chooseButton = NSButton(title: "Choose Image…", target: nil, action: nil)
    private let backgroundLabel = NSTextField(labelWithString: "No image chosen")

    private var backgroundURL: URL?
    private var backgroundPreview: CGImage?

    init?(url: URL) {
        guard let document = PDFDocument(url: url),
              let page = document.page(at: 0) else { return nil }
        self.pageCount = document.pageCount

        let bounds = page.bounds(for: .mediaBox)
        let scale = min(2.0, 1000 / max(1, bounds.width))
        let width = max(1, Int(bounds.width * scale))
        let height = max(1, Int(bounds.height * scale))
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
        guard let preview = context.makeImage() else { return nil }
        self.preview = preview

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 780),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Add Background to PDF"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)

        buildUI(url: url)
        updateBackgroundControls()
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

        let info = NSTextField(
            labelWithString: "\(pageCount) pages · pages are flattened when framed"
        )
        info.font = .systemFont(ofSize: 11)
        info.textColor = .secondaryLabelColor

        let header = NSStackView(views: [name, info])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 2

        paddingSlider.isContinuous = true
        paddingSlider.target = self
        paddingSlider.action = #selector(controlChanged)
        paddingSlider.translatesAutoresizingMaskIntoConstraints = false
        paddingSlider.widthAnchor.constraint(equalToConstant: 240).isActive = true

        paddingLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        paddingLabel.textColor = .secondaryLabelColor
        paddingLabel.translatesAutoresizingMaskIntoConstraints = false
        paddingLabel.widthAnchor.constraint(equalToConstant: 52).isActive = true

        shadowCheckbox.state = .on
        shadowCheckbox.target = self
        shadowCheckbox.action = #selector(controlChanged)

        backgroundControl.selectedSegment = 0
        backgroundControl.target = self
        backgroundControl.action = #selector(backgroundChanged)

        colorWell.color = NSColor(srgbRed: 0.96, green: 0.94, blue: 0.90, alpha: 1)
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

        let paddingTitle = NSTextField(labelWithString: "Padding")
        paddingTitle.font = .systemFont(ofSize: 12)
        paddingTitle.textColor = .secondaryLabelColor
        paddingTitle.translatesAutoresizingMaskIntoConstraints = false
        paddingTitle.widthAnchor.constraint(equalToConstant: 64).isActive = true

        let paddingRow = NSStackView(views: [paddingTitle, paddingSlider, paddingLabel])
        paddingRow.orientation = .horizontal
        paddingRow.alignment = .centerY
        paddingRow.spacing = 10

        let backgroundRow = NSStackView(views: [
            backgroundControl, colorWell, chooseButton, backgroundLabel
        ])
        backgroundRow.orientation = .horizontal
        backgroundRow.alignment = .centerY
        backgroundRow.spacing = 10

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
            header, imageView, paddingRow, shadowCheckbox, backgroundRow, buttons
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

    private func currentSpec() -> PDFFrameSpec {
        let background: PDFFrameSpec.Background
        if backgroundControl.selectedSegment == 1, let backgroundURL {
            background = .image(backgroundURL)
        } else {
            background = .color(imageColor())
        }
        return PDFFrameSpec(
            paddingPercent: paddingSlider.doubleValue / 100,
            shadow: shadowCheckbox.state == .on,
            background: background,
            dpi: 200
        )
    }

    private func updateBackgroundControls() {
        let imageMode = backgroundControl.selectedSegment == 1
        colorWell.isEnabled = !imageMode
        chooseButton.isEnabled = imageMode
    }

    private func updatePreview() {
        let spec = currentSpec()
        guard let rendered = PDFFrameEngine.renderPage(
            pageImage: preview,
            background: backgroundControl.selectedSegment == 1 ? backgroundPreview : nil,
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
        shadowCheckbox.state = .on
        backgroundControl.selectedSegment = 0
        paddingLabel.stringValue = "12%"
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
