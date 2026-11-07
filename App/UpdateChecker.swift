import Foundation
import Combine

@MainActor
final class UpdateChecker: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String, url: URL)
        case failed(String)
    }

    static let shared = UpdateChecker()

    @Published private(set) var state: State = .idle
    @Published private(set) var lastChecked: Date?

    private let autoKey = "checkForUpdatesAutomatically"
    private let lastCheckKey = "lastUpdateCheckDate"
    private var task: Task<Void, Never>?
    private var dailyTimer: Timer?

    private init() {
        let previous = UserDefaults.standard.object(forKey: lastCheckKey) as? Date
        lastChecked = previous
        // A check from the last day is still fresh; show that result instead of
        // an empty "idle" card on every relaunch.
        if let previous, Date().timeIntervalSince(previous) < 86_400 {
            state = .upToDate
        }
    }

    var automaticallyChecks: Bool {
        UserDefaults.standard.object(forKey: autoKey) as? Bool ?? true
    }

    func start() {
        guard dailyTimer == nil else { return }
        dailyTimer = Timer.scheduledTimer(withTimeInterval: 86_400, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkIfNeeded() }
        }
        checkIfNeeded()
    }

    func setAutomatic(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: autoKey)
        if enabled {
            checkIfNeeded()
        } else {
            state = .idle
        }
    }

    func checkIfNeeded() {
        guard automaticallyChecks else { return }
        if let lastChecked, Date().timeIntervalSince(lastChecked) < 86_400 { return }
        beginCheck()
    }

    func check() {
        beginCheck()
    }

    private func beginCheck() {
        guard task == nil else { return }
        state = .checking
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let release = try await Self.fetchLatestRelease()
                let current = Self.currentVersion
                if Self.isNewer(release.version, than: current) {
                    state = .available(version: release.version, url: release.url)
                } else {
                    state = .upToDate
                }
            } catch {
                state = .failed(error.localizedDescription)
            }
            let now = Date()
            lastChecked = now
            UserDefaults.standard.set(now, forKey: lastCheckKey)
            task = nil
        }
    }

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    private struct Release: Decodable {
        let tag_name: String
        let html_url: String
    }

    private struct LatestRelease {
        let version: String
        let url: URL
    }

    private enum UpdateError: LocalizedError {
        case badResponse
        case noRelease

        var errorDescription: String? {
            switch self {
            case .badResponse: return "GitHub did not return a usable release."
            case .noRelease: return "No published release was found."
            }
        }
    }

    private static func fetchLatestRelease() async throws -> LatestRelease {
        guard let url = URL(string: "https://api.github.com/repos/j4yop/DragConvert/releases/latest") else {
            throw UpdateError.noRelease
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("DragConvert/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw UpdateError.badResponse
        }
        let release = try JSONDecoder().decode(Release.self, from: data)
        guard let releaseURL = URL(string: release.html_url) else {
            throw UpdateError.noRelease
        }
        return LatestRelease(
            version: release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV")),
            url: releaseURL
        )
    }

    private static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = current.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(a.count, b.count) {
            let left = index < a.count ? a[index] : 0
            let right = index < b.count ? b[index] : 0
            if left != right { return left > right }
        }
        return false
    }
}
