import Foundation

/// Walks library roots and lists every `.tci`, `.wav` and `.aiff` file.
public enum Scanner {
    public static func scan(roots: [URL]) -> [TCIFile] {
        var seen = Set<String>()
        var results: [TCIFile] = []
        for root in roots {
            for file in scan(root: root) where !seen.contains(file.path) {
                seen.insert(file.path)
                results.append(file)
            }
        }
        return results
    }

    public static func scan(root: URL) -> [TCIFile] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: keys,
                                             options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return []
        }
        let rootPath = root.standardizedFileURL.path
        var files: [TCIFile] = []
        for case let url as URL in enumerator {
            guard let kind = FileKind.extensions[url.pathExtension.lowercased()] else { continue }
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { continue }
            files.append(make(url: url, kind: kind, rootPath: rootPath, rootName: root.lastPathComponent,
                              size: Int64(values.fileSize ?? 0),
                              modified: values.contentModificationDate ?? .distantPast))
        }
        return files
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
    static func inferLayout(rootPath: String, rootName: String, folders: [String]) -> Layout {
        var meaningful: [(name: String, path: String)] = []
        var path = rootPath
        for folder in folders {
            path += "/" + folder
            if genericFolders.contains(folder.lowercased()) { continue }
            meaningful.append((folder, path))
        }
        let rootIsPack = meaningful.isEmpty
            || Classifier.category(in: meaningful[0].name) != nil
            || Vendors.guess(text: rootName) != nil
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

    static func make(url: URL, kind: FileKind, rootPath: String, rootName: String, size: Int64, modified: Date) -> TCIFile {
        let path = url.standardizedFileURL.path
        let name = url.deletingPathExtension().lastPathComponent
        var relative = path.hasPrefix(rootPath + "/") ? String(path.dropFirst(rootPath.count + 1)) : url.lastPathComponent
        relative = (relative as NSString).deletingLastPathComponent
        let folders = relative.isEmpty ? [] : relative.components(separatedBy: "/")
        let (base, variant) = Classifier.splitVariant(name)
        let layout = inferLayout(rootPath: rootPath, rootName: rootName, folders: folders)
        return TCIFile(path: path, kind: kind, name: name, baseName: base, variant: variant,
                       root: rootPath, pack: layout.pack, packPath: layout.packPath,
                       kit: layout.kit, kitPath: layout.kitPath, folder: relative,
                       category: Classifier.category(name: name, folders: folders),
                       source: Classifier.source(name: name, folders: folders),
                       vendor: Vendors.guess(root: rootPath, folders: folders),
                       size: size, modified: modified)
    }
}
