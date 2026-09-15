import XCTest
@testable import SampleSearchKit

final class ClassifierTests: XCTestCase {
    func testVariantSplit() {
        XCTAssertEqual(Classifier.splitVariant("Snare 5 SSDR").variant, "SSDR")
        XCTAssertEqual(Classifier.splitVariant("Snare 5 SSDR").base, "Snare 5")
        XCTAssertEqual(Classifier.splitVariant("QikTom 2 Z3").variant, "Z3")
        XCTAssertNil(Classifier.splitVariant("Snare 12").variant)
        XCTAssertNil(Classifier.splitVariant("SSDR").variant)
        XCTAssertNil(Classifier.splitVariant("Big Snare Punchy").variant)
    }

    func testCategoryFromName() {
        XCTAssertEqual(Classifier.category(name: "ChiliSnare Z3", folders: []), .snare)
        XCTAssertEqual(Classifier.category(name: "ACKick Z1", folders: []), .kick)
        XCTAssertEqual(Classifier.category(name: "MapleTom 1 SSDR", folders: []), .tom)
        XCTAssertEqual(Classifier.category(name: "Custom Snare", folders: []), .snare)
        XCTAssertEqual(Classifier.category(name: "Kick Room", folders: []), .kick)
        XCTAssertEqual(Classifier.category(name: "Room Mic", folders: []), .other)
        XCTAssertEqual(Classifier.category(name: "Bottom Mic", folders: []), .other)
        XCTAssertEqual(Classifier.category(name: "Room L", folders: ["Kick"]), .kick, "room is no longer a category")
    }

    func testSource() {
        XCTAssertEqual(Classifier.source(name: "DW Kick SB OH", folders: []), .overheads)
        XCTAssertEqual(Classifier.source(name: "DW Kick SB DIR", folders: []), .direct)
        XCTAssertEqual(Classifier.source(name: "Snare 5 SSDR", folders: []), .direct)
        XCTAssertEqual(Classifier.source(name: "Kick Room", folders: []), .rooms)
        XCTAssertEqual(Classifier.source(name: "Snare Amb Far", folders: []), .rooms)
        XCTAssertEqual(Classifier.source(name: "Snare Verb Splash", folders: []), .fx)
        XCTAssertEqual(Classifier.source(name: "Take 1", folders: ["Snares", "Overheads"]), .overheads)
        XCTAssertEqual(Classifier.source(name: "Take 1", folders: ["Kick", "FX"]), .fx)
    }

    func testCategoryFallsBackToFolders() {
        XCTAssertEqual(Classifier.category(name: "Mixed 01", folders: ["Trigger2 Snares", "Snare05"]), .snare)
        XCTAssertEqual(Classifier.category(name: "MIXED", folders: ["Kit C", "Kick"]), .kick)
        XCTAssertEqual(Classifier.category(name: "Take 3", folders: ["02c Black Brass Snare (14x6.5)", "MIXED"]), .snare)
        XCTAssertEqual(Classifier.category(name: "Plain", folders: ["Stuff"]), .other)
    }

    func testSuggestRoots() {
        let home = URL(fileURLWithPath: "/Users/me")
        let files = [
            URL(fileURLWithPath: "/Users/me/Library/Mobile Documents/com~apple~CloudDocs/Documents/Trigger2Library/Snares/S1.tci"),
            URL(fileURLWithPath: "/Users/me/Library/Mobile Documents/com~apple~CloudDocs/Documents/Trigger2Library/Kicks/K1.tci"),
            URL(fileURLWithPath: "/Users/me/Downloads/MixWave TCI/Kick/MIXED/a.tci"),
        ]
        let roots = TCIFinder.suggestRoots(for: files, home: home)
        XCTAssertEqual(roots.map(\.root.path), [
            "/Users/me/Library/Mobile Documents/com~apple~CloudDocs/Documents/Trigger2Library",
            "/Users/me/Downloads/MixWave TCI",
        ])
        XCTAssertEqual(roots.map(\.count), [2, 1])
    }

    func testOldRoomCategoryOverrideBecomesRoomsSource() throws {
        let json = #"{"tags":[],"favorite":false,"category":"room","fileName":"a.tci","fileSize":1}"#.data(using: .utf8)!
        let meta = try JSONDecoder().decode(ItemMeta.self, from: json)
        XCTAssertNil(meta.category)
        XCTAssertEqual(meta.source, .rooms)
    }

    func testOldEffectCategoryKeyDecodesAsEffectType() throws {
        let json = #"{"tags":[],"favorite":false,"effectCategory":"riser","fileName":"a.wav","fileSize":1}"#.data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder().decode(ItemMeta.self, from: json).effectType, "riser")
        let lib = #"{"roots":[],"items":{}}"#.data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder().decode(LibraryData.self, from: lib).effectTypes, EffectType.defaults)
    }

    func testReconcileFollowsMovedFile() {
        var data = LibraryData()
        data.items["/old/Snare 5 SSDR.tci"] = ItemMeta(tags: ["punchy"], favorite: true, fileName: "Snare 5 SSDR.tci", fileSize: 100)
        let moved = TCIFile(path: "/new/Snare 5 SSDR.tci", name: "Snare 5 SSDR", baseName: "Snare 5", variant: "SSDR",
                            root: "/new", pack: "new", folder: "", category: .snare, size: 100, modified: .now)
        data.reconcile(with: [moved])
        XCTAssertNil(data.items["/old/Snare 5 SSDR.tci"])
        XCTAssertEqual(data.items["/new/Snare 5 SSDR.tci"]?.tags, ["punchy"])
    }
}
