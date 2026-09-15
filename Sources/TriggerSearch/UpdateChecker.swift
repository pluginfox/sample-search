import AppKit
import Foundation

/// Compares the running app's version with the latest GitHub release.
@MainActor
final class UpdateChecker: ObservableObject {
    nonisolated static let repo = "pluginfox/trigger-search"
    nonisolated static let releasesPage = URL(string: "https://github.com/\(repo)/releases/latest")!
    nonisolated static let apiURL = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!

    struct Release: Decodable {
        var tag_name: String
        var html_url: String
        var name: String?
        var body: String?
        var assets: [Asset]
        struct Asset: Decodable {
            var name: String
            var browser_download_url: String
        }
        /// Prefer a zipped app; otherwise the release page.
        var downloadURL: URL {
            let zip = assets.first { $0.name.lowercased().hasSuffix(".zip") || $0.name.lowercased().hasSuffix(".dmg") }
            return URL(string: zip?.browser_download_url ?? html_url) ?? UpdateChecker.releasesPage
        }
    }

    enum Outcome {
        case upToDate(current: String)
        case available(Release, current: String)
        case failed(String)
    }

    @Published var outcome: Outcome?
    @Published private(set) var isChecking = false

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// Runs a check. Quiet checks only report when an update exists (used at launch).
    func check(quiet: Bool = false) async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }
        var request = URLRequest(url: Self.apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Trigger-Search/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 404 {
                if !quiet { outcome = .upToDate(current: Self.currentVersion) }   // no releases yet
                return
            }
            let release = try JSONDecoder().decode(Release.self, from: data)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastUpdateCheck")
            if Self.isNewer(release.tag_name, than: Self.currentVersion) {
                outcome = .available(release, current: Self.currentVersion)
            } else if !quiet {
                outcome = .upToDate(current: Self.currentVersion)
            }
        } catch {
            if !quiet { outcome = .failed(error.localizedDescription) }
        }
    }

    /// Launch-time check at most once a day, if enabled.
    func checkAtLaunchIfDue() {
        guard UserDefaults.standard.object(forKey: "autoCheckUpdates") as? Bool ?? true else { return }
        let last = UserDefaults.standard.double(forKey: "lastUpdateCheck")
        guard Date().timeIntervalSince1970 - last > 24 * 60 * 60 else { return }
        Task { await check(quiet: true) }
    }

    /// "v1.2.3" > "1.2" etc. Compares dotted numeric components, missing ones count as 0.
    nonisolated static func isNewer(_ candidate: String, than current: String) -> Bool {
        func parts(_ s: String) -> [Int] {
            s.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
                .split(whereSeparator: { $0 == "." || $0 == "-" })
                .map { Int($0.prefix { $0.isNumber }) ?? 0 }
        }
        let a = parts(candidate), b = parts(current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
