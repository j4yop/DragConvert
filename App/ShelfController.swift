import AppKit
import SwiftUI

@MainActor
final class ShelfStore: ObservableObject {
    @Published var items: [URL] = []

    func add(_ urls: [URL]) {
        for url in urls {
            let normalised = url.standardizedFileURL
            if !items.contains(where: { $0.standardizedFileURL == normalised }) {
                items.append(url)
            }
        }
    }

    func remove(_ url: URL) {
        items.removeAll { $0.standardizedFileURL == url.standardizedFileURL }
    }
}

struct ShelfView: View {
    @ObservedObject var store: ShelfStore
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("Shelf")
                    .font(.system(size: 12, weight: .semibold))
                Text("\(store.items.count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if store.items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "tray")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text("Use FLOAT to park files here")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(store.items, id: \.self) { url in
                            HStack(spacing: 8) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                    .resizable()
                                    .frame(width: 22, height: 22)
                                Text(url.lastPathComponent)
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer(minLength: 4)
                                Button {
                                    store.remove(url)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.primary.opacity(0.06))
                            )
                            .onDrag {
                                NSItemProvider(contentsOf: url) ?? NSItemProvider()
                            }
                        }
                    }
                    .padding(8)
                }
            }
        }
        .frame(width: 230, height: 340)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

final class ShelfPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 230, height: 340),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isMovableByWindowBackground = true
    }

    override var canBecomeKey: Bool { true }
}

@MainActor
final class ShelfController {
    static let shared = ShelfController()

    private let store = ShelfStore()
    private var panel: ShelfPanel?

    private init() {}

    func add(_ urls: [URL]) {
        store.add(urls)
        show()
    }

    func toggle() {
        if panel?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    func show() {
        if panel == nil {
            let newPanel = ShelfPanel()
            newPanel.contentView = NSHostingView(
                rootView: ShelfView(store: store, onClose: { [weak self] in self?.hide() })
            )
            panel = newPanel
        }
        guard let panel, let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(
            x: visible.maxX - panel.frame.width - 20,
            y: visible.midY - panel.frame.height / 2
        ))
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }
}
