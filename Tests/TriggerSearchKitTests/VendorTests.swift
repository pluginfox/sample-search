import XCTest
@testable import TriggerSearchKit

final class VendorTests: XCTestCase {
    func testGuessesFromFolders() {
        XCTAssertEqual(Vendors.guess(root: "/x/Trigger2Library", folders: ["Trigger2 Snares", "Snare05"]), "Steven Slate Drums")
        XCTAssertEqual(Vendors.guess(root: "/x/Pack A TCI", folders: ["02a Steel Snare", "MIXED"]), "MixWave")
        XCTAssertEqual(Vendors.guess(root: "/x/Vendor One Pack C", folders: ["Kit C", "Kick"]), "Vendor One")
        XCTAssertEqual(Vendors.guess(root: "/x/Vendor Two Pack D", folders: []), "Vendor Two")
        XCTAssertEqual(Vendors.guess(root: "/x/Pack F", folders: []), "GetGood Drums")
        XCTAssertEqual(Vendors.guess(root: "/x/Samples", folders: ["Acme Audio - Big Kicks", "Kicks"]), "Acme Audio")
        XCTAssertNil(Vendors.guess(root: "/x/Samples", folders: ["Random", "Kicks"]))
    }

    func testOldLibraryFileDecodesWithoutVendors() throws {
        let json = #"{"roots":["/a"],"items":{}}"#.data(using: .utf8)!
        let data = try JSONDecoder().decode(LibraryData.self, from: json)
        XCTAssertEqual(data.roots, ["/a"])
        XCTAssertTrue(data.vendors.isEmpty)
    }
}
