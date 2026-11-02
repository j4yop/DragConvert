import AppKit

enum Sound {
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "soundEnabled") == nil
            || UserDefaults.standard.bool(forKey: "soundEnabled")
    }

    static func completion() {
        guard isEnabled else { return }
        NSSound(named: "Glass")?.play()
    }
}
