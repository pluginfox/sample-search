import XCTest
@testable import SampleSearchKit

final class ClassifierTests: XCTestCase {
    func testVariantSplit() {
        XCTAssertEqual(Classifier.splitVariant("Snare 5 SSDR").variant, "SSDR")
        XCTAssertEqual(Classifier.splitVariant("Snare 5 SSDR").base, "Snare 5")
        XCTAssertEqual(Classifier.splitVariant("FastTom 2 Z3").variant, "Z3")
        XCTAssertNil(Classifier.splitVariant("Snare 12").variant)
        XCTAssertNil(Classifier.splitVariant("SSDR").variant)
        XCTAssertNil(Classifier.splitVariant("Big Snare Punchy").variant)
    }

    func testCategoryFromName() {
        XCTAssertEqual(Classifier.category(name: "RedSnare Z3", folders: []), .snare)
        XCTAssertEqual(Classifier.category(name: "ACKick Z1", folders: []), .kick)
        XCTAssertEqual(Classifier.category(name: "OakTom 1 SSDR", folders: []), .tom)
        XCTAssertEqual(Classifier.category(name: "Custom Snare", folders: []), .snare)
        XCTAssertEqual(Classifier.category(name: "Kick Room", folders: []), .kick)
        XCTAssertEqual(Classifier.category(name: "Room Mic", folders: []), .other)
        XCTAssertEqual(Classifier.category(name: "Bottom Mic", folders: []), .other)
        XCTAssertEqual(Classifier.category(name: "Room L", folders: ["Kick"]), .kick, "room is no longer a category")
    }

    func testSource() {
        XCTAssertEqual(Classifier.source(name: "Kick A OH", folders: []), .overheads)
        XCTAssertEqual(Classifier.source(name: "Kick A DIR", folders: []), .direct)
        XCTAssertEqual(Classifier.source(name: "Snare 5 SSDR", folders: []), .direct)
        XCTAssertEqual(Classifier.source(name: "Kick Room", folders: []), .rooms)
        XCTAssertEqual(Classifier.source(name: "Close Room", folders: []), .rooms, "direct words never beat a room word")
        XCTAssertEqual(Classifier.source(name: "Dry Room Mic", folders: []), .rooms)
        XCTAssertEqual(Classifier.source(name: "OH Close", folders: []), .overheads)
        XCTAssertEqual(Classifier.source(name: "Snare Close", folders: []), .direct)
        XCTAssertEqual(Classifier.source(name: "Snare Close", folders: ["Rooms"]), .direct, "name decides before folders")
        XCTAssertEqual(Classifier.source(name: "Snare Amb Far", folders: []), .rooms)
        XCTAssertEqual(Classifier.source(name: "Snare Verb Splash", folders: []), .fx)
        XCTAssertEqual(Classifier.source(name: "Take 1", folders: ["Snares", "Overheads"]), .overheads)
        XCTAssertEqual(Classifier.source(name: "Take 1", folders: ["Kick", "FX"]), .fx)
    }

    func testLoops() {
        XCTAssertEqual(Classifier.category(name: "Kick Loop 120bpm", folders: []), .loop)
        XCTAssertEqual(Classifier.category(name: "Full Kit Groove 02", folders: []), .loop)
        XCTAssertEqual(Classifier.category(name: "Snare Fill 3", folders: []), .loop)
        XCTAssertEqual(Classifier.category(name: "Take 04", folders: ["Pack A", "Loops 95BPM"]), .loop)
        XCTAssertEqual(Classifier.category(name: "Kick Felt Beater", folders: []), .kick, "beater is not a loop word")
        XCTAssertEqual(Classifier.category(name: "Snare Filler", folders: []), .snare, "fill only counts as a whole word")
        // A "Loops" folder is a category folder, so it is never mistaken for a kit.
        XCTAssertEqual(Classifier.category(in: "Loops"), .loop)
        XCTAssertNil(SampleSearchKit.Scanner.inferLayout(rootPath: "/x/Pack A", rootName: "Pack A",
                                                         folders: ["Loops"], rootIsPack: true).kit)
    }

    func testCategoryFallsBackToFolders() {
        XCTAssertEqual(Classifier.category(name: "Mixed 01", folders: ["Snares", "Snare05"]), .snare)
        XCTAssertEqual(Classifier.category(name: "MIXED", folders: ["Kit C", "Kick"]), .kick)
        XCTAssertEqual(Classifier.category(name: "Take 3", folders: ["02c Snare (14x6.5)", "MIXED"]), .snare)
        XCTAssertEqual(Classifier.category(name: "Plain", folders: ["Stuff"]), .other)
    }

    func testSuggestRoots() {
        let home = URL(fileURLWithPath: "/Users/me")
        let files = [
            URL(fileURLWithPath: "/Users/me/Library/Mobile Documents/com~apple~CloudDocs/Documents/Pack N/Snares/S1.tci"),
            URL(fileURLWithPath: "/Users/me/Library/Mobile Documents/com~apple~CloudDocs/Documents/Pack N/Kicks/K1.tci"),
            URL(fileURLWithPath: "/Users/me/Downloads/Pack M TCI/Kick/MIXED/a.tci"),
        ]
        let roots = TCIFinder.suggestRoots(for: files, home: home)
        XCTAssertEqual(roots.map(\.root.path), [
            "/Users/me/Library/Mobile Documents/com~apple~CloudDocs/Documents/Pack N",
            "/Users/me/Downloads/Pack M TCI",
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
