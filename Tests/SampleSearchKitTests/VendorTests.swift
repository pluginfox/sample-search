import XCTest
@testable import SampleSearchKit

final class VendorTests: XCTestCase {
    func testGuessesFromFolders() {
        // Built-in keywords resolve to their vendor from the root or any folder.
        XCTAssertEqual(Vendors.guess(root: "/x/Steven Slate Library", folders: ["Trigger Snares", "Snare05"]), "Steven Slate Drums")
        XCTAssertEqual(Vendors.guess(root: "/x/Some Toontrack Pack", folders: ["Snares"]), "Toontrack")
        XCTAssertEqual(Vendors.guess(root: "/x/Samples", folders: ["GetGood Drums Vol 1"]), "GetGood Drums")
        XCTAssertEqual(Vendors.guess(root: "/x/XLN Pack", folders: []), "XLN Audio")
        // "Vendor - Product" pack names.
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
