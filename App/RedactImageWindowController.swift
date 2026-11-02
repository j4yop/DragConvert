import AppKit
import ImageEngine
import JobCore

final class RedactImageWindowController: NSWindowController {
    var onApply: ((ImageRedactSpec) -> Void)?

    private let format: String
    private let canvas = RedactCanvas()
    private let countLabel = NSTextField(labelWithString: "0 boxes")
    private let undoButton = NSButton(title: "Undo", target: nil, action: nil)
    private var redactions: [PDFRect] = []

    init?(url: URL) {
        guard let preview = ImageConvertEngine.loadPreview(at: url, maxPixel: 1400) else {
            return nil
        }
        let ext = url.pathExtension.lowercased()
        self.format = ["jpg", "jpeg", "png", "heic", "tiff"].contains(ext) ? ext : "png"

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 740),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Redact Image"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)

        buildUI(url: url)
        canvas.image = preview
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func buildUI(url: URL) {
        guard let window, let root = window.contentView else { return }

        let name = NSTextField(labelWithString: url.lastPathComponent)
        name.font = .systemFont(ofSize: 15, weight: .semibold)
        name.lineBreakMode = .byTruncatingMiddle

        let warning = NSTextField(
            wrappingLabelWithString: "Export writes a new copy with the boxed pixels replaced by solid black. The original is untouched."
        )
        warning.font = .systemFont(ofSize: 11, weight: .medium)
        warning.textColor = .systemOrange
        warning.preferredMaxLayoutWidth = 760

        let header = NSStackView(views: [name, warning])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 4

        let hint = NSTextField(
            labelWithString: "Drag a box over anything private. Add as many as you need."
        )
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor

        countLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        countLabel.textColor = .secondaryLabelColor
        countLabel.alignment = .right

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let hintRow = NSStackView(views: [hint, spacer, countLabel])
        hintRow.orientation = .horizontal
        hintRow.alignment = .centerY

        canvas.translatesAutoresizingMaskIntoConstraints = false
        canvas.wantsLayer = true
        canvas.layer?.borderWidth = 1
        canvas.layer?.borderColor = NSColor.separatorColor.cgColor
        canvas.onAdd = { [weak self] rect in
            guard let self else { return }
            self.redactions.append(rect)
            self.refresh()
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

        let stack = NSStackView(views: [header, hintRow, canvas, footer])
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

    private func refresh() {
        canvas.redactions = redactions
        countLabel.stringValue = redactions.count == 1
            ? "1 box"
            : "\(redactions.count) boxes"
        undoButton.isEnabled = !redactions.isEmpty
    }

    @objc private func undo() {
        guard !redactions.isEmpty else { return }
        redactions.removeLast()
        refresh()
    }

    @objc private func closeWindow() {
        close()
    }

    @objc private func applyRedactions() {
        guard !redactions.isEmpty else {
            NSSound.beep()
            return
        }
        onApply?(ImageRedactSpec(redactions: redactions, format: format))
        close()
    }
}
