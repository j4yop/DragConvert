import AppKit
import PDFKit
import JobCore

final class RedactPDFWindowController: NSWindowController {
    var onApply: ((PDFRedactSpec) -> Void)?

    private let pdf: PDFDocument
    private let canvas = RedactCanvas()
    private let undoButton = NSButton(title: "Undo", target: nil, action: nil)
    private let prevButton = NSButton(title: "‹", target: nil, action: nil)
    private let nextButton = NSButton(title: "›", target: nil, action: nil)
    private let pageLabel = NSTextField(labelWithString: "")

    private var redactions: [PDFRedaction] = []
    private var pageIndex = 0
    private var pageImages: [Int: CGImage] = [:]

    init?(url: URL) {
        guard let document = PDFDocument(url: url) else { return nil }
        self.pdf = document

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 880, height: 780),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Redact PDF"
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

        let warning = NSTextField(
            wrappingLabelWithString: "Pages are flattened to images when you apply. Anything under a black box is permanently removed, including text, vector shapes and embedded images."
        )
        warning.font = .systemFont(ofSize: 11, weight: .medium)
        warning.textColor = .systemOrange
        warning.preferredMaxLayoutWidth = 800

        let header = NSStackView(views: [name, warning])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 4

        let hint = NSTextField(
            labelWithString: "Drag a box over anything private. Add as many as you need."
        )
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor

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

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let toolbar = NSStackView(views: [
            hint, spacer, prevButton, pageLabel, nextButton
        ])
        toolbar.orientation = .horizontal
        toolbar.alignment = .centerY
        toolbar.spacing = 8

        canvas.translatesAutoresizingMaskIntoConstraints = false
        canvas.wantsLayer = true
        canvas.layer?.borderWidth = 1
        canvas.layer?.borderColor = NSColor.separatorColor.cgColor
        canvas.onAdd = { [weak self] rect in
            guard let self else { return }
            self.redactions.append(PDFRedaction(pageIndex: self.pageIndex, rect: rect))
            self.refreshPage()
        }

        undoButton.bezelStyle = .rounded
        undoButton.target = self
        undoButton.action = #selector(undo)
        undoButton.widthAnchor.constraint(equalToConstant: 80).isActive = true

        let cancel = NSButton(title: "Cancel", target: self, action: #selector(closeWindow))
        cancel.bezelStyle = .rounded
        cancel.widthAnchor.constraint(equalToConstant: 90).isActive = true

        let apply = NSButton(title: "Redact", target: self, action: #selector(applyRedactions))
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
            canvas.heightAnchor.constraint(greaterThanOrEqualToConstant: 440)
        ])
    }

    private func refreshPage() {
        canvas.pageIndex = pageIndex
        canvas.image = renderPage(pageIndex)
        canvas.redactions = redactions
            .filter { $0.pageIndex == pageIndex }
            .map(\.rect)
        pageLabel.stringValue = "Page \(pageIndex + 1) of \(pdf.pageCount)"
        prevButton.isEnabled = pageIndex > 0
        nextButton.isEnabled = pageIndex < pdf.pageCount - 1
        undoButton.isEnabled = redactions.contains { $0.pageIndex == pageIndex }
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
        guard let index = redactions.lastIndex(where: { $0.pageIndex == pageIndex }) else { return }
        redactions.remove(at: index)
        refreshPage()
    }

    @objc private func closeWindow() {
        close()
    }

    @objc private func applyRedactions() {
        guard !redactions.isEmpty else {
            NSSound.beep()
            return
        }
        onApply?(PDFRedactSpec(redactions: redactions, dpi: 200))
        close()
    }
}
