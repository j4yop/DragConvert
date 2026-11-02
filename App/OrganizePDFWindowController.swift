import AppKit
import PDFKit
import JobCore

struct OrganizePage {
    let id: UUID
    let sourceIndex: Int
    var rotation: Int
    var thumbnail: NSImage?
}

final class OrganizePDFWindowController: NSWindowController,
    NSCollectionViewDataSource, NSCollectionViewDelegate {

    var onApply: ((PDFOrganizeSpec) -> Void)?

    private let pdf: PDFDocument
    private var pages: [OrganizePage]
    private let collectionView = NSCollectionView()
    private let scrollView = NSScrollView()
    private let rotateButton = NSButton(title: "Rotate", target: nil, action: nil)
    private let duplicateButton = NSButton(title: "Duplicate", target: nil, action: nil)
    private let deleteButton = NSButton(title: "Delete", target: nil, action: nil)

    private let accent = NSColor(srgbRed: 1.0, green: 0.42, blue: 0.18, alpha: 1.0)

    init?(url: URL) {
        guard let document = PDFDocument(url: url) else { return nil }
        self.pdf = document
        self.pages = (0..<document.pageCount).map {
            OrganizePage(id: UUID(), sourceIndex: $0, rotation: 0)
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 940, height: 720),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Organize PDF Pages"
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

        let count = NSTextField(
            labelWithString: "\(pages.count) pages · drag to reorder"
        )
        count.font = .systemFont(ofSize: 11)
        count.textColor = .secondaryLabelColor

        let header = NSStackView(views: [name, count])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 2

        for button in [rotateButton, duplicateButton, deleteButton] {
            button.bezelStyle = .rounded
            button.font = .systemFont(ofSize: 12)
            button.target = self
        }
        rotateButton.action = #selector(rotatePage)
        duplicateButton.action = #selector(duplicatePage)
        deleteButton.action = #selector(deletePage)

        let toolbar = NSStackView(views: [rotateButton, duplicateButton, deleteButton])
        toolbar.orientation = .horizontal
        toolbar.spacing = 8

        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: 148, height: 196)
        layout.minimumInteritemSpacing = 14
        layout.minimumLineSpacing = 14
        layout.sectionInset = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        collectionView.collectionViewLayout = layout
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = false
        collectionView.register(
            PageItem.self,
            forItemWithIdentifier: PageItem.identifier
        )
        collectionView.registerForDraggedTypes([.string])
        collectionView.setDraggingSourceOperationMask(.move, forLocal: true)
        collectionView.frame = NSRect(x: 0, y: 0, width: 880, height: 460)
        collectionView.autoresizingMask = [.width]

        scrollView.documentView = collectionView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let close = NSButton(title: "Cancel", target: self, action: #selector(closeWindow))
        close.bezelStyle = .rounded
        close.widthAnchor.constraint(equalToConstant: 90).isActive = true

        let save = NSButton(title: "Save as New PDF", target: self, action: #selector(save))
        save.bezelStyle = .rounded
        save.keyEquivalent = "\r"
        save.bezelColor = accent
        save.widthAnchor.constraint(equalToConstant: 150).isActive = true

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let footer = NSStackView(views: [close, spacer, save])
        footer.orientation = .horizontal
        footer.distribution = .fill

        let stack = NSStackView(views: [header, toolbar, scrollView, footer])
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

        updateButtons()
    }

    private var selectedIndex: Int? {
        collectionView.selectionIndexPaths.first?.item
    }

    private func updateButtons() {
        let hasSelection = selectedIndex != nil
        rotateButton.isEnabled = hasSelection
        duplicateButton.isEnabled = hasSelection
        deleteButton.isEnabled = hasSelection && pages.count > 1
    }

    // MARK: Data source

    func collectionView(
        _ collectionView: NSCollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        pages.count
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        itemForRepresentedObjectAt indexPath: IndexPath
    ) -> NSCollectionViewItem {
        let item = collectionView.makeItem(
            withIdentifier: PageItem.identifier,
            for: indexPath
        ) as! PageItem

        var page = pages[indexPath.item]
        if page.thumbnail == nil {
            page.thumbnail = pdf.page(at: page.sourceIndex)?
                .thumbnail(of: NSSize(width: 300, height: 400), for: .mediaBox)
            pages[indexPath.item] = page
        }
        item.configure(page: page, index: indexPath.item)
        return item
    }

    // MARK: Selection

    func collectionView(
        _ collectionView: NSCollectionView,
        didSelectItemsAt indexPaths: Set<IndexPath>
    ) {
        updateButtons()
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        didDeselectItemsAt indexPaths: Set<IndexPath>
    ) {
        updateButtons()
    }

    // MARK: Drag & drop

    func collectionView(
        _ collectionView: NSCollectionView,
        pasteboardWriterForItemAt indexPath: IndexPath
    ) -> NSPasteboardWriting? {
        let item = NSPasteboardItem()
        item.setString(pages[indexPath.item].id.uuidString, forType: .string)
        return item
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        validateDrop draggingInfo: NSDraggingInfo,
        proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>,
        dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>
    ) -> NSDragOperation {
        proposedDropOperation.pointee = .before
        return .move
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        acceptDrop draggingInfo: NSDraggingInfo,
        indexPath: IndexPath,
        dropOperation: NSCollectionView.DropOperation
    ) -> Bool {
        guard let string = draggingInfo.draggingPasteboard.string(forType: .string),
              let id = UUID(uuidString: string),
              let from = pages.firstIndex(where: { $0.id == id })
        else { return false }

        var to = indexPath.item
        let page = pages.remove(at: from)
        if from < to { to -= 1 }
        to = max(0, min(to, pages.count))
        pages.insert(page, at: to)
        collectionView.reloadData()
        updateButtons()
        return true
    }

    // MARK: Actions

    @objc private func rotatePage() {
        guard let index = selectedIndex else { return }
        pages[index].rotation = (pages[index].rotation + 1) % 4
        collectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
    }

    @objc private func duplicatePage() {
        guard let index = selectedIndex else { return }
        let source = pages[index]
        let copy = OrganizePage(
            id: UUID(),
            sourceIndex: source.sourceIndex,
            rotation: source.rotation,
            thumbnail: source.thumbnail
        )
        pages.insert(copy, at: index + 1)
        collectionView.reloadData()
        updateButtons()
    }

    @objc private func deletePage() {
        guard let index = selectedIndex, pages.count > 1 else { return }
        pages.remove(at: index)
        collectionView.reloadData()
        updateButtons()
    }

    @objc private func closeWindow() {
        close()
    }

    @objc private func save() {
        guard !pages.isEmpty else { return }
        let spec = PDFOrganizeSpec(pages: pages.map {
            PDFPageEdit(sourceIndex: $0.sourceIndex, rotation: $0.rotation)
        })
        onApply?(spec)
        close()
    }
}

// MARK: - Item

final class PageItem: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("PageItem")

    private let thumbnail = NSImageView()
    private let numberLabel = NSTextField(labelWithString: "")
    private let badge = NSTextField(labelWithString: "")

    override func loadView() {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 8
        container.layer?.borderWidth = 2
        container.layer?.borderColor = NSColor.clear.cgColor
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        thumbnail.imageScaling = .scaleProportionallyUpOrDown
        thumbnail.imageAlignment = .alignCenter
        thumbnail.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(thumbnail)

        numberLabel.font = .systemFont(ofSize: 11, weight: .medium)
        numberLabel.textColor = .secondaryLabelColor
        numberLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(numberLabel)

        badge.font = .systemFont(ofSize: 10, weight: .semibold)
        badge.textColor = NSColor(srgbRed: 1.0, green: 0.42, blue: 0.18, alpha: 1.0)
        badge.alignment = .right
        badge.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(badge)

        NSLayoutConstraint.activate([
            thumbnail.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            thumbnail.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            thumbnail.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            thumbnail.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -28),

            numberLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            numberLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -7),

            badge.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            badge.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -7)
        ])

        view = container
    }

    override var isSelected: Bool {
        didSet {
            view.layer?.borderColor = isSelected
                ? NSColor(srgbRed: 1.0, green: 0.42, blue: 0.18, alpha: 1.0).cgColor
                : NSColor.clear.cgColor
        }
    }

    func configure(page: OrganizePage, index: Int) {
        thumbnail.image = page.thumbnail
        numberLabel.stringValue = "Page \(index + 1)"
        let turns = ((page.rotation % 4) + 4) % 4
        badge.stringValue = turns == 0 ? "" : "↻ \(turns * 90)°"
        badge.isHidden = turns == 0
    }
}
