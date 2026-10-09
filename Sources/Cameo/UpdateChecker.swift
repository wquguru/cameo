import Foundation

/// Checks GitHub Releases once a day for a version newer than the running one.
/// Failures (offline, rate-limited, or the repository not public) are silent.
@MainActor
final class UpdateChecker {
    struct Update: Equatable {
        let version: String
        let url: URL
    }

    static let latestRelease = URL(string: "https://api.github.com/repos/wquguru/cameo/releases/latest")!
    private let onUpdate: (Update?) -> Void
    private var timer: Timer?

    init(onUpdate: @escaping (Update?) -> Void) {
        self.onUpdate = onUpdate
    }

    func start() {
        Task { await check() }
        timer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            Task { await self?.check() }
        }
    }

    func check() async {
        var request = URLRequest(url: Self.latestRelease)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let release = try? JSONDecoder().decode(Release.self, from: data),
              let url = URL(string: release.html_url) else { return }
        let latest = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
        let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        onUpdate(Self.isNewer(latest, than: current) ? Update(version: latest, url: url) : nil)
    }

    /// Compares dotted numeric versions: "0.10.0" is newer than "0.9.1".
    nonisolated static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }
        let y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
            if l != r { return l > r }
        }
        return false
    }

    private struct Release: Decodable {
        let tag_name: String
        let html_url: String
    }
}
