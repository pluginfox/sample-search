import XCTest
@testable import TriggerSearchKit

/// Only runs when the user's real library exists; prints a category breakdown for eyeballing.
final class RealLibraryTests: XCTestCase {
    func testScanRealLibraryIfPresent() throws {
        let root = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Mobile Documents/com~apple~CloudDocs/Documents/Trigger2Library")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: root.path))
        let extras = ["Vendor One Pack C", "Pack A TCI", "Vendor Two Pack D", "Pack F"]
            .map { URL(fileURLWithPath: NSHomeDirectory() + "/Downloads/" + $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        let files = Scanner.scan(roots: [root] + extras)
        XCTAssertGreaterThan(files.count, 0)
        var counts: [DrumCategory: Int] = [:]
        for f in files { counts[f.category, default: 0] += 1 }
        print("SCAN: \(files.count) files; categories:", counts.map { "\($0.key.rawValue)=\($0.value)" }.sorted().joined(separator: " "))
        var sources: [SourceType: Int] = [:]
        for f in files { sources[f.source, default: 0] += 1 }
        print("SOURCES:", sources.map { "\($0.key.rawValue)=\($0.value)" }.sorted().joined(separator: " "))
        for f in files where f.source != .direct { print("SRC:", f.source.rawValue, f.folder, "/", f.name) }
        print("PACKS:", Set(files.map(\.pack)).sorted())
        print("KITS:", Set(files.compactMap { f in f.kit.map { f.pack + " > " + $0 } }).sorted())
        print("VARIANTS:", Set(files.compactMap(\.variant)).sorted())
        for f in files where f.category == .other { print("OTHER:", f.folder, "/", f.name) }
    }
}
