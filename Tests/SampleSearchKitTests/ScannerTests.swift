import XCTest
@testable import SampleSearchKit

final class ScannerTests: XCTestCase {
    func testScanPicksUpInstrumentsAndOneShots() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ts-scan-\(UUID().uuidString)")
        let kicks = root.appendingPathComponent("My Pack/Kicks")
        try FileManager.default.createDirectory(at: kicks, withIntermediateDirectories: true)
        for name in ["Kick A SSDR.tci", "Kick 01.wav", "Kick 02.AIFF", "Kick 03.aif", "readme.txt", "cover.png"] {
            try Data("x".utf8).write(to: kicks.appendingPathComponent(name))
        }
        defer { try? FileManager.default.removeItem(at: root) }

        let files = Scanner.scan(roots: [root]).sorted { $0.name < $1.name }
        XCTAssertEqual(files.map(\.name), ["Kick 01", "Kick 02", "Kick 03", "Kick A SSDR"])
        XCTAssertEqual(files.map(\.kind), [.oneShot, .oneShot, .oneShot, .instrument])
        XCTAssertEqual(files.map(\.formatName), ["WAV", "AIFF", "AIF", "TCI"])
        XCTAssertEqual(Set(files.map(\.pack)), ["My Pack"])
        XCTAssertEqual(Set(files.map(\.folder)), ["My Pack/Kicks"])
        XCTAssertEqual(Set(files.map(\.category)), [.kick])
        XCTAssertEqual(Set(files.map(\.packPath)), [root.standardizedFileURL.path + "/My Pack"])
    }

    func testCollectionRootKeepsDrumNamedFoldersAsPacks() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ts-coll-\(UUID().uuidString)")
        let layout: [String: [String]] = [
            "Pack H Snares/Kit H": ["BB Snare 1.tci"],
            "Pack I_s Samples/Crash Samples": ["Crash A.tci"],
            "Pack F": ["P5 Kick.tci"],
            "Pack J Kicks": ["DK 1.tci"],
            "Pack G/Kit A": ["AG Snare.tci"],
        ]
        for (dir, names) in layout {
            let d = root.appendingPathComponent(dir)
            try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
            for n in names { try Data("x".utf8).write(to: d.appendingPathComponent(n)) }
        }
        defer { try? FileManager.default.removeItem(at: root) }
        let files = SampleSearchKit.Scanner.scan(roots: [root])
        let packs = Dictionary(uniqueKeysWithValues: files.map { ($0.name, $0.pack) })
        XCTAssertEqual(packs["BB Snare 1"], "Pack H Snares")
        XCTAssertEqual(packs["Crash A"], "Pack I_s Samples")
        XCTAssertEqual(packs["DK 1"], "Pack J Kicks")
        XCTAssertEqual(packs["P5 Kick"], "Pack F")
        XCTAssertEqual(files.first { $0.name == "BB Snare 1" }?.kit, "Kit H")
        XCTAssertNil(files.first { $0.name == "Crash A" }?.kit, "category-named subfolder is not a kit")
        XCTAssertEqual(files.first { $0.name == "AG Snare" }?.kit, "Kit A")

        // A root whose subfolders are mostly categories is itself the pack.
        XCTAssertTrue(SampleSearchKit.Scanner.rootIsPackDecision(rootName: "Trigger2Library",
            firstLevelFolders: ["Trigger2 Snares", "Trigger2 Kicks", "Trigger2 Toms", "Trigger2 Deluxe"]))
        XCTAssertFalse(SampleSearchKit.Scanner.rootIsPackDecision(rootName: "Trigger Samples",
            firstLevelFolders: ["Pack H Snares", "Pack I_s Samples", "Pack F", "Pack J Kicks", "Pack G"]))
        XCTAssertFalse(Classifier.category(in: "Pack I_s Samples") != nil, "'s' alone is not a snare")
    }

    func testEffectsRootsScanAudioAsEffects() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ts-fx-\(UUID().uuidString)")
        let dir = root.appendingPathComponent("Cinematic Pack/Risers")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for name in ["808 Sub Drop.wav", "Big Riser 01.wav", "Crash Swell.wav", "Impact Boom.aiff", "Reverse Cymbal.wav", "Snare Hit.wav", "notes.tci"] {
            try Data("x".utf8).write(to: dir.appendingPathComponent(name))
        }
        defer { try? FileManager.default.removeItem(at: root) }
        let files = SampleSearchKit.Scanner.scan(roots: [], effectRoots: [root]).sorted { $0.name < $1.name }
        XCTAssertEqual(files.map(\.name), ["808 Sub Drop", "Big Riser 01", "Crash Swell", "Impact Boom", "Reverse Cymbal", "Snare Hit"], ".tci ignored in effects roots")
        XCTAssertTrue(files.allSatisfy { $0.kind == .effect })
        XCTAssertEqual(files.map(\.effectType), ["subdrop", "riser", "cymbal", "impact", "reverse", "hit"])

        // Custom types: list order is priority, unknown stays nil (Other).
        let custom = [EffectType(id: "swell", name: "Swells", singular: "Swell", symbol: "sun.max", keywords: ["swell"])] + EffectType.defaults
        XCTAssertEqual(Classifier.effectType(name: "Crash Swell", folders: [], types: custom), "swell")
        XCTAssertNil(Classifier.effectType(name: "Mystery 01", folders: [], types: custom))
        XCTAssertEqual(EffectType.resolve("swell", in: custom).name, "Swells")
        XCTAssertEqual(EffectType.resolve("nope", in: custom).id, "other")
        XCTAssertEqual(Set(files.map(\.pack)), ["Cinematic Pack"])
    }

    func testPackAndKitInference() {
        func layout(_ root: String, _ folders: [String]) -> SampleSearchKit.Scanner.Layout {
            SampleSearchKit.Scanner.inferLayout(rootPath: "/x/" + root, rootName: root, folders: folders)
        }
        // Category folders directly under the root: root is the pack, no kit.
        XCTAssertEqual(layout("Trigger2Library", ["Trigger2 Snares", "Snare05"]),
                       SampleSearchKit.Scanner.Layout(pack: "Trigger2Library", packPath: "/x/Trigger2Library"))
        XCTAssertEqual(layout("Pack A TCI", ["01a Kick (Gretsch)", "MIXED"]),
                       SampleSearchKit.Scanner.Layout(pack: "Pack A TCI", packPath: "/x/Pack A TCI"))
        // Vendor-named root with kit folders inside.
        XCTAssertEqual(layout("Vendor One Pack C", ["Kit C", "Kick"]),
                       SampleSearchKit.Scanner.Layout(pack: "Vendor One Pack C", packPath: "/x/Vendor One Pack C",
                             kit: "Kit C", kitPath: "/x/Vendor One Pack C/Kit C"))
        // Generic wrapper folders are skipped.
        XCTAssertEqual(layout("Vendor Two Pack D", ["TCI", "TCI", "01 RAW", "01 SNARE 1", "01 LO"]),
                       SampleSearchKit.Scanner.Layout(pack: "Vendor Two Pack D", packPath: "/x/Vendor Two Pack D",
                             kit: "01 RAW", kitPath: "/x/Vendor Two Pack D/TCI/TCI/01 RAW"))
        // Generic root holding several packs: first folder is the pack, next non-category folder the kit.
        XCTAssertEqual(layout("Samples", ["Acme Drums Vol 1", "Kit A", "Kicks"]),
                       SampleSearchKit.Scanner.Layout(pack: "Acme Drums Vol 1", packPath: "/x/Samples/Acme Drums Vol 1",
                             kit: "Kit A", kitPath: "/x/Samples/Acme Drums Vol 1/Kit A"))
        XCTAssertEqual(layout("Samples", ["Acme Drums Vol 1", "Kicks"]),
                       SampleSearchKit.Scanner.Layout(pack: "Acme Drums Vol 1", packPath: "/x/Samples/Acme Drums Vol 1"))
        XCTAssertEqual(layout("Pack F", []), SampleSearchKit.Scanner.Layout(pack: "Pack F", packPath: "/x/Pack F"))
    }
}
