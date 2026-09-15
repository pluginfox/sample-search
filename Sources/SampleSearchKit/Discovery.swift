import Foundation

/// Finds `.tci` files anywhere on the Mac via Spotlight and proposes library roots.
@MainActor
public final class TCIFinder: NSObject {
    private var query: NSMetadataQuery?
    private var continuation: CheckedContinuation<[URL], Never>?

    public override init() { super.init() }

    /// All `.tci` files Spotlight knows about.
    public func findAll() async -> [URL] {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            let query = NSMetadataQuery()
            query.predicate = NSPredicate(format: "kMDItemFSName ENDSWITH[c] %@", ".tci")
            query.searchScopes = [NSMetadataQueryUserHomeScope, NSMetadataQueryLocalComputerScope]
            NotificationCenter.default.addObserver(self, selector: #selector(finished(_:)),
                                                   name: .NSMetadataQueryDidFinishGathering, object: query)
            self.query = query
            if !query.start() {
                self.query = nil
                self.continuation = nil
                continuation.resume(returning: [])
            }
        }
    }

    @objc private func finished(_ note: Notification) {
        guard let query else { return }
        query.disableUpdates()
        query.stop()
        var urls: [URL] = []
        for i in 0..<query.resultCount {
            if let item = query.result(at: i) as? NSMetadataItem,
               let path = item.value(forAttribute: NSMetadataItemPathKey) as? String {
                urls.append(URL(fileURLWithPath: path))
            }
        }
        NotificationCenter.default.removeObserver(self)
        self.query = nil
        continuation?.resume(returning: urls)
        continuation = nil
    }

    /// Folder names that are generic containers rather than sample libraries.
    nonisolated static let genericContainers: Set<String> = [
        "users", "volumes", "downloads", "documents", "desktop", "music", "library", "mobile documents",
        "com~apple~clouddocs", "shared", "samples", "sample libraries", "audio", "dropbox", "google drive",
        "onedrive", "icloud drive", "public", "movies", "pictures", "application support",
    ]

    /// Groups files into suggested roots: the first folder under the generic containers
    /// (e.g. `~/Downloads/Pack A TCI`), with the number of files inside.
    nonisolated public static func suggestRoots(for files: [URL], home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [(root: URL, count: Int)] {
        let homeName = home.lastPathComponent.lowercased()
        var counts: [String: Int] = [:]
        for file in files {
            let components = file.standardizedFileURL.pathComponents.dropFirst() // drop "/"
            var chosen: [String] = []
            var acc: [String] = []
            for component in components.dropLast() {
                acc.append(component)
                let lower = component.lowercased()
                if genericContainers.contains(lower) || lower == homeName || lower == "trigger" { continue }
                chosen = acc
                break
            }
            if chosen.isEmpty { chosen = Array(components.dropLast()) }
            guard !chosen.isEmpty else { continue }
            counts["/" + chosen.joined(separator: "/"), default: 0] += 1
        }
        return counts.map { (URL(fileURLWithPath: $0.key), $0.value) }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.path < $1.0.path }
    }
}
