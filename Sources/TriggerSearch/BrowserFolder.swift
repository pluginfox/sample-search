import Foundation
import TriggerSearchKit

/// Where the Trigger-browsable link folder lives, and how rows map onto exporter entries.
enum BrowserFolder {
    static let defaultsKey = "browserFolder"

    static var url: URL {
        get {
            if let path = UserDefaults.standard.string(forKey: defaultsKey) { return URL(fileURLWithPath: path) }
            return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Music/Trigger Search")
        }
        set { UserDefaults.standard.set(newValue.path, forKey: defaultsKey) }
    }

    static func entries(for rows: [Row]) -> [BrowserEntry] {
        rows.map { row in
            var groups: [String] = []
            if row.favorite { groups.append("Favourites") }
            groups += row.tags.map { "Tags/\(BrowserFolderExporter.safe($0))" }
            if !row.kit.isEmpty {
                groups.append("Kits/\(BrowserFolderExporter.safe(row.pack))/\(BrowserFolderExporter.safe(row.kit))")
            }
            groups.append("Categories/\(row.category.displayName)/\(row.sourceName)")
            groups.append("Sources/\(row.sourceName)")
            let vendor = BrowserFolderExporter.safe(row.vendor.isEmpty ? "Unknown" : row.vendor)
            var vendorPath = "Vendors/\(vendor)/\(BrowserFolderExporter.safe(row.pack))"
            if !row.kit.isEmpty { vendorPath += "/\(BrowserFolderExporter.safe(row.kit))" }
            groups.append(vendorPath)
            return BrowserEntry(url: row.file.url, pack: row.pack, groups: groups)
        }
    }

    static func export(rows: [Row], selection: [Row], to base: URL = url) throws -> BrowserFolderExporter.Result {
        let result = try BrowserFolderExporter.export(entries(for: rows), to: base)
        try BrowserFolderExporter.setTopLevel(entries(for: selection), in: base)
        return result
    }

    static func syncSelection(_ selection: [Row], to base: URL = url) throws {
        try BrowserFolderExporter.setTopLevel(entries(for: selection), in: base)
    }
}
