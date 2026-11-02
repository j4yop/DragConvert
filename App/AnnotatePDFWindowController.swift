import AppKit
import PDFKit
import JobCore

final class AnnotatePDFWindowController: NSWindowController, NSTextFieldDelegate {
    var onApply: ((PDFAnnotateSpec) -> Void)?

    private let pdf: PDFDocument
    private let canvas = AnnotateCanvas()
    private let toolControl = NSSegmentedControl(
        labels: ["Text", "Rect", "Ellipse", "Arrow", "Ink"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let colorWell = NSColorWell()
    private let noteField = NSTextField()
    private let undoButton = NSButton(title: "Undo", target: nil, action: nil)
    private let prevButton = NSButton(title: "‹", target: nil, action: nil)
    private let nextButton = NSButton(title: "›", target: nil, action: nil)
    private let pageLabel = NSTextField(labelWithString: "")

    private var annotations: [PDFAnnotationSpec] = []
    private var pageIndex = 0
    private var pageImages: [Int: CGImage] = [:]

    private let kinds: [PDFAnnotationSpec.Kind] = [
        .text, .rectangle, .ellipse, .arrow, .ink
    ]

    init?(url: URL) {
        guard let document = PDFDocument(url: url) else { return nil }
        self.pdf = document

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 880, height: 780),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Annotate PDF"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)

        buildUI(url: url)
        refreshPage()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func buildUI(url: URL) {
        guard let window, let root = window.contentView else { return }

        let name = NSTextField(labelWithString: url.lastPathComponent)
        name.font = .systemFont(ofSize: 15, weight: .semibold)
        name.lineBreakMode = .byTruncatingMiddle

        let hint = NSTextField(
            labelWithString: "Pick a tool, then draw on the page. Text uses the note field."
        )
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor

        let header = NSStackView(views: [name, hint])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 2

        toolControl.target = self
        toolControl.action = #selector(toolChanged)
        toolControl.selectedSegment = 1
        toolControl.setContentHuggingPriority(.required, for: .horizontal)

        colorWell.color = .systemRed
        colorWell.target = self
        colorWell.action = #selector(colorChanged)
        colorWell.translatesAutoresizingMaskIntoConstraints = false
        colorWell.widthAnchor.constraint(equalToConstant: 44).isActive = true
        colorWell.heightAnchor.constraint(equalToConstant: 24).isActive = true

        noteField.placeholderString = "Note text"
        noteField.font = .systemFont(ofSize: 12)
        noteField.delegate = self
        noteField.translatesAutoresizingMaskIntoConstraints = false
        noteField.widthAnchor.constraint(equalToConstant: 170).isActive = true

        for button in [prevButton, nextButton] {
            button.bezelStyle = .rounded
            button.target = self
        }
        prevButton.action = #selector(previousPage)
        nextButton.action = #selector(nextPage)
        prevButton.widthAnchor.constraint(equalToConstant: 34).isActive = true
        nextButton.widthAnchor.constraint(equalToConstant: 34).isActive = true

        pageLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        pageLabel.alignment = .center
        pageLabel.translatesAutoresizingMaskIntoConstraints = false
        pageLabel.widthAnchor.constraint(equalToConstant: 92).isActive = true

        let toolbarSpacer = NSView()
        toolbarSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let toolbar = NSStackView(views: [
            toolControl, colorWell, noteField, toolbarSpacer,
            prevButton, pageLabel, nextButton
        ])
        toolbar.orientation = .horizontal
        toolbar.alignment = .centerY
        toolbar.spacing = 10

        canvas.translatesAutoresizingMaskIntoConstraints = false
        canvas.wantsLayer = true
        canvas.layer?.borderWidth = 1
        canvas.layer?.borderColor = NSColor.separatorColor.cgColor
        canvas.tool = .rectangle
        canvas.color = .systemRed
        canvas.onAdd = { [weak self] spec in
            guard let self else { return }
            self.annotations.append(spec)
            self.refreshPage()
        }

        undoButton.bezelStyle = .rounded
        undoButton.target = self
        undoButton.action = #selector(undo)
        undoButton.widthAnchor.constraint(equalToConstant: 80).isActive = true

        let cancel = NSButton(title: "Cancel", target: self, action: #selector(closeWindow))
        cancel.bezelStyle = .rounded
        cancel.widthAnchor.constraint(equalToConstant: 90).isActive = true

        let apply = NSButton(title: "Apply", target: self, action: #selector(applyAnnotations))
        apply.bezelStyle = .rounded
        apply.keyEquivalent = "\r"
        apply.bezelColor = NSColor(srgbRed: 1.0, green: 0.42, blue: 0.18, alpha: 1.0)
        apply.widthAnchor.constraint(equalToConstant: 90).isActive = true

        let footerSpacer = NSView()
        footerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let footer = NSStackView(views: [undoButton, footerSpacer, cancel, apply])
        footer.orientation = .horizontal
        footer.distribution = .fill

        let stack = NSStackView(views: [header, toolbar, canvas, footer])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            canvas.heightAnchor.constraint(greaterThanOrEqualToConstant: 460)
        ])

        toolChanged()
    }

    private func refreshPage() {
        canvas.pageIndex = pageIndex
        canvas.image = renderPage(pageIndex)
        canvas.annotations = annotations.filter { $0.pageIndex == pageIndex }
        pageLabel.stringValue = "Page \(pageIndex + 1) of \(pdf.pageCount)"
        prevButton.isEnabled = pageIndex > 0
        nextButton.isEnabled = pageIndex < pdf.pageCount - 1
        undoButton.isEnabled = annotations.contains { $0.pageIndex == pageIndex }
    }

    private func renderPage(_ index: Int) -> CGImage? {
        if let cached = pageImages[index] { return cached }
        guard let page = pdf.page(at: index) else { return nil }
        let bounds = page.bounds(for: .mediaBox)
        let scale = min(2.0, 1300 / max(1, bounds.width))
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
        let image = context.makeImage()
        pageImages[index] = image
        return image
    }

    // MARK: Actions

    @objc private func toolChanged() {
        let index = max(0, min(toolControl.selectedSegment, kinds.count - 1))
        canvas.tool = kinds[index]
        noteField.isEnabled = canvas.tool == .text
    }

    @objc private func colorChanged() {
        canvas.color = colorWell.color
    }

    func controlTextDidChange(_ obj: Notification) {
        canvas.noteText = noteField.stringValue
    }

    @objc private func previousPage() {
        guard pageIndex > 0 else { return }
        pageIndex -= 1
        refreshPage()
    }

    @objc private func nextPage() {
        guard pageIndex < pdf.pageCount - 1 else { return }
        pageIndex += 1
        refreshPage()
    }

    @objc private func undo() {
        guard let index = annotations.lastIndex(where: { $0.pageIndex == pageIndex }) else { return }
        annotations.remove(at: index)
        refreshPage()
    }

    @objc private func closeWindow() {
        close()
    }

    @objc private func applyAnnotations() {
        guard !annotations.isEmpty else {
            NSSound.beep()
            return
        }
        onApply?(PDFAnnotateSpec(annotations: annotations))
        close()
    }
}
