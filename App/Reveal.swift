import AppKit

enum Reveal {
    static func ifEnabled(_ urls: [URL]) {
        guard UserDefaults.standard.bool(forKey: "revealOnFinish"),
              !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }
}
