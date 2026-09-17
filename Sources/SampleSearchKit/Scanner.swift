import Foundation

/// Walks library roots and lists every `.tci`, `.wav` and `.aiff` file.
public enum Scanner {
    /// Scans Trigger-library roots (tci + wav/aiff one-shots) and Effects roots (wav/aiff as effects).
    public static func scan(roots: [URL], effectRoots: [URL] = [], effectTypes: [EffectType] = EffectType.defaults) -> [TCIFile] {
        var seen = Set<String>()
        var results: [TCIFile] = []
        let all = roots.map({ ($0, false) }) + effectRoots.map({ ($0, true) })
        for (root, effects) in all {
            for file in scan(root: root, asEffects: effects, effectTypes: effectTypes) where !seen.contains(file.path) {
                seen.insert(file.path)
                results.append(file)
            }
        }
        return results
    }

    public static func scan(root: URL, asEffects: Bool = false, effectTypes: [EffectType] = EffectType.defaults) -> [TCIFile] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: keys,
                                             options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return []
        }
        let rootPath = root.standardizedFileURL.path
        var found: [(url: URL, kind: FileKind, size: Int64, modified: Date)] = []
        for case let url as URL in enumerator {
            guard var kind = FileKind.extensions[url.pathExtension.lowercased()] else { continue }
            if asEffects {
                guard kind == .oneShot else { continue }   // Effects folders hold audio files only
                kind = .effect
            }
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { continue }
            found.append((url, kind, Int64(values.fileSize ?? 0), values.contentModificationDate ?? .distantPast))
        }
        // Decide once per root whether the root itself is the pack, from all its first-level folders.
        let firstLevel = Set(found.compactMap { entry -> String? in
            let rel = relativeFolders(of: entry.url, rootPath: rootPath)
            return rel.first { !genericFolders.contains($0.lowercased()) }
        })
        let rootIsPack = rootIsPackDecision(rootName: root.lastPathComponent, firstLevelFolders: firstLevel)
        return found.map { entry in
            make(url: entry.url, kind: entry.kind, rootPath: rootPath, rootName: root.lastPathComponent,
                 size: entry.size, modified: entry.modified, rootIsPack: rootIsPack, effectTypes: effectTypes)
        }
    }

    /// The root is the pack when it names a vendor/product, holds files directly, or when most of
    /// its first-level folders are category folders ("Trigger2 Snares", "Kicks"). A root that is a
    /// collection of many packs (some with drum words in their names) keeps each folder as a pack.
    public static func rootIsPackDecision(rootName: String, firstLevelFolders: Set<String>) -> Bool {
        if Vendors.guess(text: rootName) != nil { return true }
        if firstLevelFolders.isEmpty { return true }
        let categoryLike = firstLevelFolders.filter { Classifier.category(in: $0) != nil }.count
        return categoryLike * 2 > firstLevelFolders.count
    }

    static func relativeFolders(of url: URL, rootPath: String) -> [String] {
        let path = url.standardizedFileURL.path
        var relative = path.hasPrefix(rootPath + "/") ? String(path.dropFirst(rootPath.count + 1)) : url.lastPathComponent
        relative = (relative as NSString).deletingLastPathComponent
        return relative.isEmpty ? [] : relative.components(separatedBy: "/")
    }

    public struct Layout: Equatable {
        public var pack: String
        public var packPath: String
        public var kit: String?
        public var kitPath: String?
    }

    /// Wrapper folders that carry no meaning ("TCI/TCI/…", "Samples").
    static let genericFolders: Set<String> = [
        "tci", "tci files", "samples", "sample", "wav", "wavs", "aiff", "aif", "trigger", "trigger 2",
        "trigger2", "library", "one shots", "one-shots", "oneshots", "content", "instruments",
    ]

    /// Pack: the first meaningful folder under the root, unless that folder is a category
    /// ("Trigger2 Snares", "01a Kick (...)") or the root itself names a vendor/product, in which case
    /// the root is the pack. Kit: the next meaningful folder inside the pack, unless it is a category.
    static func inferLayout(rootPath: String, rootName: String, folders: [String], rootIsPack forced: Bool? = nil) -> Layout {
        var meaningful: [(name: String, path: String)] = []
        var path = rootPath
        for folder in folders {
            path += "/" + folder
            if genericFolders.contains(folder.lowercased()) { continue }
            meaningful.append((folder, path))
        }
        let rootIsPack = meaningful.isEmpty || (forced ?? (Classifier.category(in: meaningful[0].name) != nil
                                                          || Vendors.guess(text: rootName) != nil))
        var layout: Layout
        var next: Int
        if rootIsPack {
            layout = Layout(pack: rootName, packPath: rootPath)
            next = 0
        } else {
            layout = Layout(pack: meaningful[0].name, packPath: meaningful[0].path)
            next = 1
        }
        if next < meaningful.count, Classifier.category(in: meaningful[next].name) == nil {
            layout.kit = meaningful[next].name
            layout.kitPath = meaningful[next].path
        }
        return layout
    }

    static func make(url: URL, kind: FileKind, rootPath: String, rootName: String, size: Int64, modified: Date,
                     rootIsPack: Bool? = nil, effectTypes: [EffectType] = EffectType.defaults) -> TCIFile {
        let path = url.standardizedFileURL.path
        let name = url.deletingPathExtension().lastPathComponent
        var relative = path.hasPrefix(rootPath + "/") ? String(path.dropFirst(rootPath.count + 1)) : url.lastPathComponent
        relative = (relative as NSString).deletingLastPathComponent
        let folders = relative.isEmpty ? [] : relative.components(separatedBy: "/")
        let (base, variant) = Classifier.splitVariant(name)
        let layout = inferLayout(rootPath: rootPath, rootName: rootName, folders: folders, rootIsPack: rootIsPack)
        return TCIFile(path: path, kind: kind, name: name, baseName: base, variant: variant,
                       root: rootPath, pack: layout.pack, packPath: layout.packPath,
                       kit: layout.kit, kitPath: layout.kitPath, folder: relative,
                       category: Classifier.category(name: name, folders: folders),
                       source: Classifier.source(name: name, folders: folders),
                       effectType: kind == .effect ? Classifier.effectType(name: name, folders: folders, types: effectTypes) : nil,
                       vendor: Vendors.guess(root: rootPath, folders: folders),
                       size: size, modified: modified)
    }
}
