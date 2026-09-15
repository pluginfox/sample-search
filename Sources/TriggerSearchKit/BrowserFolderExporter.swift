import Foundation

/// One sample plus the groups it belongs to, as the exporter needs it.
public struct BrowserEntry {
    public var url: URL
    public var pack: String
    public var groups: [String]   // relative folders, e.g. "Favourites", "Tags/punchy", "Kits/Vendor One/Kit C"

    public init(url: URL, pack: String, groups: [String]) {
        self.url = url
        self.pack = pack
        self.groups = groups
    }
}

/// Writes a folder of symlinks that a folder-based browser (Trigger 2's) can navigate.
public enum BrowserFolderExporter {
    public static let markerName = ".trigger-search-browser-folder"

    public struct Result: Equatable {
        public var links = 0
        public var folders = 0
    }

    public struct NotOursError: LocalizedError {
        public let path: String
        public var errorDescription: String? {
            "“\(path)” already exists and was not created by Trigger Search. Choose an empty or new folder."
        }
    }

    /// Rebuilds `base` from scratch. Refuses to clear a folder it did not create.
    public static func export(_ entries: [BrowserEntry], to base: URL) throws -> Result {
        let fm = FileManager.default
        let marker = base.appendingPathComponent(markerName)
        if fm.fileExists(atPath: base.path) {
            guard fm.fileExists(atPath: marker.path) else { throw NotOursError(path: base.path) }
            try fm.removeItem(at: base)
        }
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        try Data().write(to: marker)

        var result = Result()
        var made = Set<String>()
        for entry in entries {
            let ext = entry.url.pathExtension
            let stem = entry.url.deletingPathExtension().lastPathComponent
            for group in entry.groups {
                let dir = base.appendingPathComponent(group, isDirectory: true)
                if made.insert(group).inserted {
                    try fm.createDirectory(at: dir, withIntermediateDirectories: true)
                    result.folders += 1
                }
                var target = dir.appendingPathComponent(entry.url.lastPathComponent)
                if fm.fileExists(atPath: target.path) || (try? target.checkResourceIsReachable()) == true || isSymlink(target) {
                    target = dir.appendingPathComponent("\(stem) (\(safe(entry.pack))).\(ext)")
                }
                var n = 2
                while isSymlink(target) {
                    target = dir.appendingPathComponent("\(stem) (\(safe(entry.pack)) \(n)).\(ext)")
                    n += 1
                }
                try fm.createSymbolicLink(at: target, withDestinationURL: entry.url)
                result.links += 1
            }
        }
        return result
    }

    /// Replaces the symlinks sitting directly in `base` (not the group folders) with links to `entries`,
    /// so the app's current selection is visible at the top level of a folder browser. Creates the
    /// folder if needed; refuses to touch a folder it did not create.
    @discardableResult
    public static func setTopLevel(_ entries: [BrowserEntry], in base: URL) throws -> Int {
        let fm = FileManager.default
        let marker = base.appendingPathComponent(markerName)
        if fm.fileExists(atPath: base.path) {
            guard fm.fileExists(atPath: marker.path) else { throw NotOursError(path: base.path) }
        } else {
            try fm.createDirectory(at: base, withIntermediateDirectories: true)
            try Data().write(to: marker)
        }
        for name in try fm.contentsOfDirectory(atPath: base.path) {
            let item = base.appendingPathComponent(name)
            if isSymlink(item) { try fm.removeItem(at: item) }
        }
        var written = 0
        for entry in entries {
            let ext = entry.url.pathExtension
            let stem = entry.url.deletingPathExtension().lastPathComponent
            var target = base.appendingPathComponent(entry.url.lastPathComponent)
            if isSymlink(target) || fm.fileExists(atPath: target.path) {
                target = base.appendingPathComponent("\(stem) (\(safe(entry.pack))).\(ext)")
            }
            var n = 2
            while isSymlink(target) || fm.fileExists(atPath: target.path) {
                target = base.appendingPathComponent("\(stem) (\(safe(entry.pack)) \(n)).\(ext)")
                n += 1
            }
            try fm.createSymbolicLink(at: target, withDestinationURL: entry.url)
            written += 1
        }
        return written
    }

    /// `fileExists` follows symlinks, so a dangling link would look absent; check the link itself.
    static func isSymlink(_ url: URL) -> Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil
    }

    /// Makes a tag / pack / kit name safe as a single path component.
    public static func safe(_ name: String) -> String {
        name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
    }
}
