import AppKit
import ImageEngine

final class MetadataWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    var onStrip: (() -> Void)?

    private let rows: [MetadataRow]
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()

    init(url: URL) {
        self.rows = ImageMetadata.rows(for: url)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 640),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Image Metadata"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)

        buildUI(url: url)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func buildUI(url: URL) {
        guard let window, let root = window.contentView else { return }

        let nameLabel = NSTextField(labelWithString: url.lastPathComponent)
        nameLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        nameLabel.lineBreakMode = .byTruncatingMiddle

        let countLabel = NSTextField(
            labelWithString: rows.isEmpty
                ? "No embedded metadata found"
                : "\(rows.count) fields"
        )
        countLabel.font = .systemFont(ofSize: 11)
        countLabel.textColor = .secondaryLabelColor

        let header = NSStackView(views: [nameLabel, countLabel])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 2

        let banner = NSStackView()
        if ImageMetadata.hasLocation(rows) {
            let icon = NSImageView()
            icon.image = NSImage(
                systemSymbolName: "location.fill",
                accessibilityDescription: nil
            )
            icon.contentTintColor = .systemOrange
            let label = NSTextField(
                labelWithString: "This file contains location data."
            )
            label.font = .systemFont(ofSize: 12, weight: .medium)
            label.textColor = .systemOrange
            banner.setViews([icon, label], in: .leading)
            banner.orientation = .horizontal
            banner.spacing = 6
        }
        banner.isHidden = !ImageMetadata.hasLocation(rows)

        configureTable()

        let close = NSButton(title: "Close", target: self, action: #selector(closeWindow))
        close.bezelStyle = .rounded
        close.widthAnchor.constraint(equalToConstant: 90).isActive = true

        let strip = NSButton(
            title: "Strip Metadata",
            target: self,
            action: #selector(stripMetadata)
        )
        strip.bezelStyle = .rounded
        strip.bezelColor = NSColor(srgbRed: 1.0, green: 0.42, blue: 0.18, alpha: 1.0)
        strip.keyEquivalent = "\r"
        strip.isEnabled = !rows.isEmpty
        strip.widthAnchor.constraint(equalToConstant: 140).isActive = true

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttons = NSStackView(views: [close, spacer, strip])
        buttons.orientation = .horizontal
        buttons.distribution = .fill

        let stack = NSStackView(views: [header, banner, scrollView, buttons])
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
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 420)
        ])
    }

    private func configureTable() {
        let group = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("group"))
        group.title = "Group"
        group.width = 86

        let field = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("field"))
        field.title = "Field"
        field.width = 150

        let value = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("value"))
        value.title = "Value"
        value.width = 340
        value.resizingMask = .autoresizingMask

        tableView.addTableColumn(group)
        tableView.addTableColumn(field)
        tableView.addTableColumn(value)
        tableView.headerView = NSTableHeaderView()
        tableView.rowHeight = 22
        tableView.intercellSpacing = NSSize(width: 8, height: 2)
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsColumnReordering = false

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
    }

    // MARK: Table

    func numberOfRows(in tableView: NSTableView) -> Int {
        rows.count
    }

    func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        guard let tableColumn, row < rows.count else { return nil }
        let item = rows[row]
        let text: String
        switch tableColumn.identifier.rawValue {
        case "group": text = item.group.uppercased()
        case "field": text = item.field
        default: text = item.value
        }

        let label = NSTextField(labelWithString: text)
        label.lineBreakMode = .byTruncatingTail
        switch tableColumn.identifier.rawValue {
        case "group":
            label.font = .systemFont(ofSize: 9, weight: .semibold)
            label.textColor = .secondaryLabelColor
        case "field":
            label.font = .systemFont(ofSize: 12, weight: .medium)
        default:
            label.font = .systemFont(ofSize: 12)
            label.textColor = .labelColor
        }
        return label
    }

    // MARK: Actions

    @objc private func closeWindow() {
        close()
    }

    @objc private func stripMetadata() {
        onStrip?()
        close()
    }
}
