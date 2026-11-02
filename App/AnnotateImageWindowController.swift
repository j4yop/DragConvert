import AppKit
import ImageEngine
import JobCore

final class AnnotateImageWindowController: NSWindowController, NSTextFieldDelegate {
    var onApply: ((ImageAnnotateSpec) -> Void)?

    private let format: String
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

    private var annotations: [PDFAnnotationSpec] = []
    private let kinds: [PDFAnnotationSpec.Kind] = [
        .text, .rectangle, .ellipse, .arrow, .ink
    ]

    init?(url: URL) {
        guard let preview = ImageConvertEngine.loadPreview(at: url, maxPixel: 1400) else {
            return nil
        }
        let ext = url.pathExtension.lowercased()
        self.format = ["jpg", "jpeg", "png", "heic", "tiff"].contains(ext) ? ext : "png"

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 760),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Annotate Image"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)

        buildUI(url: url)
        canvas.image = preview
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func buildUI(url: URL) {
        guard let window, let root = window.contentView else { return }

        let name = NSTextField(labelWithString: url.lastPathComponent)
        name.font = .systemFont(ofSize: 15, weight: .semibold)
        name.lineBreakMode = .byTruncatingMiddle

        let hint = NSTextField(
            labelWithString: "Pick a tool, then draw on the image. Text uses the note field. Export bakes the marks into a new copy."
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
        noteField.widthAnchor.constraint(equalToConstant: 180).isActive = true

        let toolbarSpacer = NSView()
        toolbarSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let toolbar = NSStackView(views: [
            toolControl, colorWell, noteField, toolbarSpacer
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
        canvas.pageIndex = 0
        canvas.onAdd = { [weak self] spec in
            guard let self else { return }
            self.annotations.append(spec)
            self.refresh()
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

    private func refresh() {
        canvas.annotations = annotations
        undoButton.isEnabled = !annotations.isEmpty
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

    @objc private func undo() {
        guard !annotations.isEmpty else { return }
        annotations.removeLast()
        refresh()
    }

    @objc private func closeWindow() {
        close()
    }

    @objc private func applyAnnotations() {
        guard !annotations.isEmpty else {
            NSSound.beep()
            return
        }
        onApply?(ImageAnnotateSpec(annotations: annotations, format: format))
        close()
    }
}
