import XCTest
@testable import TriggerSearchKit

final class BrowserFolderExporterTests: XCTestCase {
    var tmp: URL!

    override func setUpWithError() throws {
        tmp = FileManager.default.temporaryDirectory.appendingPathComponent("ts-export-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    func testWritesLinksAndResolvesNameCollisions() throws {
        let a = tmp.appendingPathComponent("PackA/Kick.tci")
        let b = tmp.appendingPathComponent("PackB/Kick.tci")
        for f in [a, b] {
            try FileManager.default.createDirectory(at: f.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("x".utf8).write(to: f)
        }
        let base = tmp.appendingPathComponent("Browser")
        let entries = [
            BrowserEntry(url: a, pack: "Pack A", groups: ["Favourites", "Tags/punchy", "Categories/Kicks"]),
            BrowserEntry(url: b, pack: "Pack B", groups: ["Favourites", "Kits/Pack B/Kit 1", "Categories/Kicks"]),
        ]
        let result = try BrowserFolderExporter.export(entries, to: base)
        XCTAssertEqual(result, .init(links: 6, folders: 4))

        let favourites = try FileManager.default.contentsOfDirectory(atPath: base.appendingPathComponent("Favourites").path).sorted()
        XCTAssertEqual(favourites, ["Kick (Pack B).tci", "Kick.tci"])
        let link = base.appendingPathComponent("Favourites/Kick (Pack B).tci")
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: link.path), b.path)
        XCTAssertEqual(try Data(contentsOf: link), Data("x".utf8), "link resolves to the real file")
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("Kits/Pack B/Kit 1/Kick.tci").path))

        // Re-export replaces everything (no stale links) and leaves the originals untouched.
        let again = try BrowserFolderExporter.export([entries[0]], to: base)
        XCTAssertEqual(again.links, 3)
        XCTAssertFalse(FileManager.default.fileExists(atPath: base.appendingPathComponent("Kits").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: b.path))
    }

    func testTopLevelSelectionReplacesOnlyLinks() throws {
        let a = tmp.appendingPathComponent("A.tci"), b = tmp.appendingPathComponent("B.tci")
        try Data("a".utf8).write(to: a)
        try Data("b".utf8).write(to: b)
        let base = tmp.appendingPathComponent("Browser")
        _ = try BrowserFolderExporter.export([BrowserEntry(url: a, pack: "P", groups: ["Favourites"])], to: base)
        XCTAssertEqual(try BrowserFolderExporter.setTopLevel([BrowserEntry(url: a, pack: "P", groups: []),
                                                              BrowserEntry(url: b, pack: "P", groups: [])], in: base), 2)
        var names = try FileManager.default.contentsOfDirectory(atPath: base.path).filter { !$0.hasPrefix(".") }.sorted()
        XCTAssertEqual(names, ["A.tci", "B.tci", "Favourites"])
        XCTAssertEqual(try BrowserFolderExporter.setTopLevel([BrowserEntry(url: b, pack: "P", groups: [])], in: base), 1)
        names = try FileManager.default.contentsOfDirectory(atPath: base.path).filter { !$0.hasPrefix(".") }.sorted()
        XCTAssertEqual(names, ["B.tci", "Favourites"], "group folders survive, old selection links go")
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("Favourites/A.tci").path))
    }

    func testRefusesToClearAFolderItDidNotCreate() throws {
        let base = tmp.appendingPathComponent("Precious")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        try Data("keep".utf8).write(to: base.appendingPathComponent("notes.txt"))
        XCTAssertThrowsError(try BrowserFolderExporter.export([], to: base)) { error in
            XCTAssertTrue(error is BrowserFolderExporter.NotOursError)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: base.appendingPathComponent("notes.txt").path))
    }
}
