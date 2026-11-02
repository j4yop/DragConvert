import AppKit
import PDFKit
import JobCore

final class SplitPDFWindowController: NSWindowController {
    var onApply: ((PDFSplitSpec) -> Void)?

    private let pageCount: Int
    private let modeControl = NSSegmentedControl(
        labels: ["At pages", "Equal parts"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let pagesField = NSTextField()
    private let partsField = NSTextField()
    private let pagesRow = NSStackView()
    private let partsRow = NSStackView()

    init(url: URL) {
        self.pageCount = PDFDocument(url: url)?.pageCount ?? 0

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Split PDF"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)

        buildUI(url: url)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func buildUI(url: URL) {
        guard let window, let root = window.contentView else { return }

        let name = NSTextField(labelWithString: url.lastPathComponent)
        name.font = .systemFont(ofSize: 15, weight: .semibold)
        name.lineBreakMode = .byTruncatingMiddle

        let pages = NSTextField(
            labelWithString: pageCount == 1 ? "1 page" : "\(pageCount) pages"
        )
        pages.font = .systemFont(ofSize: 11)
        pages.textColor = .secondaryLabelColor

        let header = NSStackView(views: [name, pages])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 2

        modeControl.target = self
        modeControl.action = #selector(modeChanged(_:))
        modeControl.selectedSegment = 0

        let pagesLabel = NSTextField(labelWithString: "Split before pages")
        pagesLabel.font = .systemFont(ofSize: 12)
        pagesLabel.textColor = .secondaryLabelColor

        pagesField.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        pagesField.placeholderString = "3, 7"
        pagesField.isBezeled = true
        pagesField.translatesAutoresizingMaskIntoConstraints = false
        pagesField.widthAnchor.constraint(equalToConstant: 100).isActive = true

        pagesRow.setViews([pagesLabel, pagesField], in: .leading)
        pagesRow.orientation = .horizontal
        pagesRow.alignment = .centerY
        pagesRow.spacing = 8

        let partsLabel = NSTextField(labelWithString: "Number of parts")
        partsLabel.font = .systemFont(ofSize: 12)
        partsLabel.textColor = .secondaryLabelColor

        partsField.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        partsField.isBezeled = true
        partsField.stringValue = "2"
        partsField.translatesAutoresizingMaskIntoConstraints = false
        partsField.widthAnchor.constraint(equalToConstant: 100).isActive = true
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 2
        formatter.maximum = 500
        formatter.allowsFloats = false
        partsField.formatter = formatter

        partsRow.setViews([partsLabel, partsField], in: .leading)
        partsRow.orientation = .horizontal
        partsRow.alignment = .centerY
        partsRow.spacing = 8

        let hint = NSTextField(
            wrappingLabelWithString: "Parts are written to a new folder beside the PDF, named “part 1.pdf”, “part 2.pdf”, and so on."
        )
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .tertiaryLabelColor
        hint.preferredMaxLayoutWidth = 440

        let reset = NSButton(title: "Reset", target: self, action: #selector(resetDefaults))
        reset.bezelStyle = .rounded
        reset.widthAnchor.constraint(equalToConstant: 90).isActive = true

        let apply = NSButton(title: "Apply", target: self, action: #selector(applySplit))
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
            header, modeControl, pagesRow, partsRow, hint, buttons
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

        modeChanged(modeControl)
        resetDefaults()
    }

    @objc private func modeChanged(_ sender: NSSegmentedControl) {
        let atPages = sender.selectedSegment == 0
        pagesField.isEnabled = atPages
        partsField.isEnabled = !atPages
    }

    @objc private func resetDefaults() {
        modeControl.selectedSegment = 0
        pagesField.stringValue = ""
        partsField.stringValue = "2"
        modeChanged(modeControl)
    }

    @objc private func applySplit() {
        let spec: PDFSplitSpec
        if modeControl.selectedSegment == 0 {
            let pages = pagesField.stringValue
                .split(whereSeparator: { $0 == "," || $0 == " " })
                .compactMap { Int($0) }
                .filter { $0 > 1 && $0 <= pageCount }
            let unique = Array(Set(pages)).sorted()
            guard !unique.isEmpty else {
                NSSound.beep()
                return
            }
            spec = PDFSplitSpec(mode: .atPages, pages: unique)
        } else {
            let parts = max(2, min(Int(partsField.stringValue) ?? 2, max(2, pageCount)))
            spec = PDFSplitSpec(mode: .equalParts, parts: parts)
        }
        onApply?(spec)
        close()
    }
}
