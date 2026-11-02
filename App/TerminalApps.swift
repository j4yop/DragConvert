import AppKit

struct TerminalChoice: Identifiable, Hashable {
    let id: String
    let name: String
}

enum TerminalApps {
    /// Only terminals that are actually installed are offered. Add a known
    /// bundle identifier here rather than asking the user to type one.
    private static let known: [(String, String)] = [
        ("Terminal", "com.apple.Terminal"),
        ("iTerm2", "com.googlecode.iterm2"),
        ("Warp", "dev.warp.Warp-Stable"),
        ("Ghostty", "com.mitchellh.ghostty"),
        ("kitty", "net.kovidgoyal.kitty"),
        ("WezTerm", "com.github.wez.wezterm"),
        ("Alacritty", "org.alacritty")
    ]

    static var installed: [TerminalChoice] {
        known.compactMap { name, bundleID in
            guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil else {
                return nil
            }
            return TerminalChoice(id: bundleID, name: name)
        }
    }

    static var selectedBundleID: String {
        let saved = UserDefaults.standard.string(forKey: "terminalBundleID")
            ?? "com.apple.Terminal"
        if NSWorkspace.shared.urlForApplication(withBundleIdentifier: saved) != nil {
            return saved
        }
        return "com.apple.Terminal"
    }

    static var selectedURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: selectedBundleID)
            ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal")
    }
}
