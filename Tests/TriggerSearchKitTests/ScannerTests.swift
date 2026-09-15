import XCTest
@testable import TriggerSearchKit

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

    func testEffectsRootsScanAudioAsEffects() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ts-fx-\(UUID().uuidString)")
        let dir = root.appendingPathComponent("Cinematic Pack/Risers")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for name in ["Big Riser 01.wav", "Impact Boom.aiff", "Reverse Cymbal.wav", "Snare Hit.wav", "notes.tci"] {
            try Data("x".utf8).write(to: dir.appendingPathComponent(name))
        }
        defer { try? FileManager.default.removeItem(at: root) }
        let files = TriggerSearchKit.Scanner.scan(roots: [], effectRoots: [root]).sorted { $0.name < $1.name }
        XCTAssertEqual(files.map(\.name), ["Big Riser 01", "Impact Boom", "Reverse Cymbal", "Snare Hit"], ".tci ignored in effects roots")
        XCTAssertTrue(files.allSatisfy { $0.kind == .effect })
        XCTAssertEqual(files.map(\.effectCategory), [.riser, .impact, .reverse, .hit])
        XCTAssertEqual(Set(files.map(\.pack)), ["Cinematic Pack"])
    }

    func testPackAndKitInference() {
        func layout(_ root: String, _ folders: [String]) -> TriggerSearchKit.Scanner.Layout {
            TriggerSearchKit.Scanner.inferLayout(rootPath: "/x/" + root, rootName: root, folders: folders)
        }
        // Category folders directly under the root: root is the pack, no kit.
        XCTAssertEqual(layout("Trigger2Library", ["Trigger2 Snares", "Snare05"]),
                       TriggerSearchKit.Scanner.Layout(pack: "Trigger2Library", packPath: "/x/Trigger2Library"))
        XCTAssertEqual(layout("Pack A TCI", ["01a Kick (Gretsch)", "MIXED"]),
                       TriggerSearchKit.Scanner.Layout(pack: "Pack A TCI", packPath: "/x/Pack A TCI"))
        // Vendor-named root with kit folders inside.
        XCTAssertEqual(layout("Vendor One Pack C", ["Kit C", "Kick"]),
                       TriggerSearchKit.Scanner.Layout(pack: "Vendor One Pack C", packPath: "/x/Vendor One Pack C",
                             kit: "Kit C", kitPath: "/x/Vendor One Pack C/Kit C"))
        // Generic wrapper folders are skipped.
        XCTAssertEqual(layout("Vendor Two Pack D", ["TCI", "TCI", "01 RAW", "01 SNARE 1", "01 LO"]),
                       TriggerSearchKit.Scanner.Layout(pack: "Vendor Two Pack D", packPath: "/x/Vendor Two Pack D",
                             kit: "01 RAW", kitPath: "/x/Vendor Two Pack D/TCI/TCI/01 RAW"))
        // Generic root holding several packs: first folder is the pack, next non-category folder the kit.
        XCTAssertEqual(layout("Samples", ["Acme Drums Vol 1", "Kit A", "Kicks"]),
                       TriggerSearchKit.Scanner.Layout(pack: "Acme Drums Vol 1", packPath: "/x/Samples/Acme Drums Vol 1",
                             kit: "Kit A", kitPath: "/x/Samples/Acme Drums Vol 1/Kit A"))
        XCTAssertEqual(layout("Samples", ["Acme Drums Vol 1", "Kicks"]),
                       TriggerSearchKit.Scanner.Layout(pack: "Acme Drums Vol 1", packPath: "/x/Samples/Acme Drums Vol 1"))
        XCTAssertEqual(layout("Pack F", []), TriggerSearchKit.Scanner.Layout(pack: "Pack F", packPath: "/x/Pack F"))
    }
}
