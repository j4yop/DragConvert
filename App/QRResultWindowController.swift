import AppKit

final class QRResultWindowController: NSWindowController {
    private let values: [String]
    private let textView = NSTextView()

    init(values: [String], source: URL) {
        self.values = values

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "QR Code"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)

        buildUI(source: source)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func buildUI(source: URL) {
        guard let window, let root = window.contentView else { return }

        let name = NSTextField(labelWithString: source.lastPathComponent)
        name.font = .systemFont(ofSize: 15, weight: .semibold)
        name.lineBreakMode = .byTruncatingMiddle

        let status = NSTextField(
            labelWithString: values.isEmpty
                ? "No QR code found"
                : (values.count == 1 ? "1 code found" : "\(values.count) codes found")
        )
        status.font = .systemFont(ofSize: 11)
        status.textColor = values.isEmpty ? .systemOrange : .secondaryLabelColor

        let header = NSStackView(views: [name, status])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 2

        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.string = values.isEmpty
            ? "No QR code found in this image."
            : values.joined(separator: "\n\n")
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: 0, height: CGFloat.greatestFiniteMagnitude
        )

        let scroll = NSScrollView()
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.heightAnchor.constraint(equalToConstant: 230).isActive = true

        let copy = NSButton(title: "Copy", target: self, action: #selector(copyValue))
        copy.bezelStyle = .rounded
        copy.isEnabled = !values.isEmpty
        copy.widthAnchor.constraint(equalToConstant: 90).isActive = true

        let open = NSButton(title: "Open Link", target: self, action: #selector(openLink))
        open.bezelStyle = .rounded
        open.isEnabled = values.count == 1 && URL(string: values[0])?.scheme != nil
        open.widthAnchor.constraint(equalToConstant: 100).isActive = true

        let close = NSButton(title: "Close", target: self, action: #selector(closeWindow))
        close.bezelStyle = .rounded
        close.keyEquivalent = "\r"
        close.widthAnchor.constraint(equalToConstant: 90).isActive = true

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttons = NSStackView(views: [copy, open, spacer, close])
        buttons.orientation = .horizontal
        buttons.spacing = 8
        buttons.distribution = .fill

        let stack = NSStackView(views: [header, scroll, buttons])
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

    @objc private func copyValue() {
        guard !values.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(values.joined(separator: "\n"), forType: .string)
    }

    @objc private func openLink() {
        guard values.count == 1,
              let url = URL(string: values[0]),
              url.scheme != nil else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func closeWindow() {
        close()
    }
}
