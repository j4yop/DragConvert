import AppKit
import AVFoundation
import Foundation

/// Shared sound + haptic language for the wheel, HUD and editors.
/// The tick is generated for DragConvert (not copied from another app).
@MainActor
public final class Feedback {
    public static let shared = Feedback()

    private var tickPlayer: AVAudioPlayer?

    private init() {
        guard let url = Bundle.module.url(forResource: "highlight", withExtension: "wav") else {
            return
        }
        tickPlayer = try? AVAudioPlayer(contentsOf: url)
        tickPlayer?.prepareToPlay()
    }

    private var soundsOn: Bool {
        let defaults = UserDefaults.standard
        if let value = defaults.object(forKey: "soundEnabled") as? Bool { return value }
        if let value = defaults.object(forKey: "soundsEnabled") as? Bool { return value }
        return true
    }

    private var hapticsOn: Bool {
        let defaults = UserDefaults.standard
        if let value = defaults.object(forKey: "hapticsEnabled") as? Bool { return value }
        return true
    }

    public func open() {
        haptic(.levelChange)
        tick(volume: 0.18)
    }

    public func hover() {
        haptic(.alignment)
        tick(volume: 0.22)
    }

    public func select() {
        haptic(.levelChange)
        tick(volume: 0.42)
    }

    public func success() {
        haptic(.generic)
        systemSound("Glass", volume: 0.30)
    }

    public func failure() {
        haptic(.generic)
        systemSound("Basso", volume: 0.26)
    }

    public func cancel() {
        haptic(.alignment)
        systemSound("Pop", volume: 0.16)
    }

    public func note() {
        haptic(.alignment)
    }

    private func haptic(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        guard hapticsOn else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(
            pattern,
            performanceTime: .now
        )
    }

    private func tick(volume: Float) {
        guard soundsOn, let tickPlayer else { return }
        tickPlayer.stop()
        tickPlayer.currentTime = 0
        tickPlayer.volume = volume
        tickPlayer.play()
    }

    private func systemSound(_ name: String, volume: Float) {
        guard soundsOn, let sound = NSSound(named: NSSound.Name(name)) else { return }
        sound.volume = volume
        sound.play()
    }
}
