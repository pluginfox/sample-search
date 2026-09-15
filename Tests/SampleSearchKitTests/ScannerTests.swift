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
            "Alpha Snares 1/Brass Tuning 1": ["BB Snare 1.tci"],
            "Beta_s Organized Samples/Crash Samples": ["Crash A.tci"],
            "Vendor P5": ["P5 Kick.tci"],
            "Pack J Kicks": ["DK 1.tci"],
            "Some Drummer/Kit A": ["AG Snare.tci"],
        ]
        for (dir, names) in layout {
            let d = root.appendingPathComponent(dir)
            try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
            for n in names { try Data("x".utf8).write(to: d.appendingPathComponent(n)) }
        }
        defer { try? FileManager.default.removeItem(at: root) }
        let files = SampleSearchKit.Scanner.scan(roots: [root])
        let packs = Dictionary(uniqueKeysWithValues: files.map { ($0.name, $0.pack) })
        XCTAssertEqual(packs["BB Snare 1"], "Alpha Snares 1")
        XCTAssertEqual(packs["Crash A"], "Beta_s Organized Samples")
        XCTAssertEqual(packs["DK 1"], "Pack J Kicks")
        XCTAssertEqual(packs["P5 Kick"], "Vendor P5")
        XCTAssertEqual(files.first { $0.name == "BB Snare 1" }?.kit, "Brass Tuning 1")
        XCTAssertNil(files.first { $0.name == "Crash A" }?.kit, "category-named subfolder is not a kit")
        XCTAssertEqual(files.first { $0.name == "AG Snare" }?.kit, "Kit A")

        // A root whose subfolders are mostly categories is itself the pack.
        XCTAssertTrue(SampleSearchKit.Scanner.rootIsPackDecision(rootName: "TriggerLibrary",
            firstLevelFolders: ["Trigger Snares", "Trigger Kicks", "Trigger Toms", "Trigger Deluxe"]))
        XCTAssertFalse(SampleSearchKit.Scanner.rootIsPackDecision(rootName: "Trigger Samples",
            firstLevelFolders: ["Alpha Snares 1", "Beta_s Organized Samples", "Vendor P5", "Pack J Kicks", "Some Drummer"]))
        XCTAssertFalse(Classifier.category(in: "Beta_s Organized Samples") != nil, "'s' alone is not a snare")
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
        XCTAssertEqual(layout("TriggerLibrary", ["Trigger Snares", "Snare05"]),
                       SampleSearchKit.Scanner.Layout(pack: "TriggerLibrary", packPath: "/x/TriggerLibrary"))
        XCTAssertEqual(layout("Acme Pack TCI", ["01a Kick (Gretsch)", "MIXED"]),
                       SampleSearchKit.Scanner.Layout(pack: "Acme Pack TCI", packPath: "/x/Acme Pack TCI"))
        // Vendor-named root with kit folders inside.
        XCTAssertEqual(layout("Toontrack Samples Historic Edition", ["The Hall", "Kick"]),
                       SampleSearchKit.Scanner.Layout(pack: "Toontrack Samples Historic Edition", packPath: "/x/Toontrack Samples Historic Edition",
                             kit: "The Hall", kitPath: "/x/Toontrack Samples Historic Edition/The Hall"))
        // Generic wrapper folders are skipped.
        XCTAssertEqual(layout("XLN Audio Snares V1", ["TCI", "TCI", "01 RAW", "01 SNARE 1", "01 LO"]),
                       SampleSearchKit.Scanner.Layout(pack: "XLN Audio Snares V1", packPath: "/x/XLN Audio Snares V1",
                             kit: "01 RAW", kitPath: "/x/XLN Audio Snares V1/TCI/TCI/01 RAW"))
        // Generic root holding several packs: first folder is the pack, next non-category folder the kit.
        XCTAssertEqual(layout("Samples", ["Acme Drums Vol 1", "Kit A", "Kicks"]),
                       SampleSearchKit.Scanner.Layout(pack: "Acme Drums Vol 1", packPath: "/x/Samples/Acme Drums Vol 1",
                             kit: "Kit A", kitPath: "/x/Samples/Acme Drums Vol 1/Kit A"))
        XCTAssertEqual(layout("Samples", ["Acme Drums Vol 1", "Kicks"]),
                       SampleSearchKit.Scanner.Layout(pack: "Acme Drums Vol 1", packPath: "/x/Samples/Acme Drums Vol 1"))
        XCTAssertEqual(layout("Vendor P5", []), SampleSearchKit.Scanner.Layout(pack: "Vendor P5", packPath: "/x/Vendor P5"))
    }
}
