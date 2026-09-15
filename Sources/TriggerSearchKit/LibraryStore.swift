import Foundation

/// Loads and saves `LibraryData` as JSON in Application Support.
public struct LibraryStore {
    public let fileURL: URL

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.fileURL = base.appendingPathComponent("Trigger Search", isDirectory: true)
                .appendingPathComponent("library.json")
        }
    }

    public func load() -> LibraryData {
        guard let data = try? Data(contentsOf: fileURL) else { return LibraryData() }
        return (try? JSONDecoder().decode(LibraryData.self, from: data)) ?? LibraryData()
    }

    public func save(_ library: LibraryData) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(library).write(to: fileURL, options: .atomic)
    }
}

public extension LibraryData {
    /// Re-attaches metadata to files that moved: if a path with metadata no longer exists but exactly
    /// one scanned file has the same name and size, the metadata follows it.
    mutating func reconcile(with files: [TCIFile]) {
        let present = Set(files.map(\.path))
        let orphans = items.filter { !present.contains($0.key) && !$0.value.isEmpty }
        guard !orphans.isEmpty else { return }
        var byIdentity: [String: [TCIFile]] = [:]
        for file in files where items[file.path] == nil {
            byIdentity["\(file.url.lastPathComponent)|\(file.size)", default: []].append(file)
        }
        for (oldPath, meta) in orphans {
            let key = "\(meta.fileName)|\(meta.fileSize)"
            if let candidates = byIdentity[key], candidates.count == 1 {
                items[candidates[0].path] = meta
                items.removeValue(forKey: oldPath)
                byIdentity.removeValue(forKey: key)
            }
        }
    }
}
