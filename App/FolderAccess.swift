import AppKit

/// Owns the one-time home-folder security-scoped bookmark.
///
/// A dropped file grants access to that file, not to its parent folder, so
/// writing "beside the original" needs folder access.
@MainActor
final class FolderAccess {
    static let shared = FolderAccess()

    private let defaultsKey = "homeFolderBookmark"
    private var activeURL: URL?

    var isGranted: Bool { activeURL != nil }

    @discardableResult
    func ensureAccess(promptIfNeeded: Bool = true) -> Bool {
        if restore() { return true }
        guard promptIfNeeded else { return false }
        return prompt()
    }

    @discardableResult
    func prompt() -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        panel.message = "Allow access to your home folder so results can be saved next to the originals."
        panel.prompt = "Allow"

        guard panel.runModal() == .OK, let url = panel.url else { return false }
        store(url)
        activeURL = url
        _ = url.startAccessingSecurityScopedResource()
        return true
    }

    private func restore() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            Log.write("folder access: no bookmark")
            return false
        }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else {
            Log.write("folder access: bookmark did not resolve")
            return false
        }
        let started = url.startAccessingSecurityScopedResource()
        Log.write("folder access: restored=\(started) path=\(url.path)")
        guard started else { return false }

        activeURL = url
        if stale { store(url) }
        return true
    }

    private func store(_ url: URL) {
        guard let data = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
