import XCTest
@testable import SampleSearchKit

final class VendorTests: XCTestCase {
    override func setUp() {
        super.setUp()
        saved = Vendors.keywords
        Vendors.keywords = TestVendors.keywords
    }

    override func tearDown() {
        Vendors.keywords = saved
        super.tearDown()
    }

    private var saved: [(String, String)] = []

    func testGuessesFromFolders() {
        // Keywords resolve to their vendor from the root or any folder.
        XCTAssertEqual(Vendors.guess(root: "/x/Acme Library", folders: ["Trigger Snares", "Snare05"]), "Acme Audio")
        XCTAssertEqual(Vendors.guess(root: "/x/Some Bolt Pack", folders: ["Snares"]), "Bolt Drums")
        XCTAssertEqual(Vendors.guess(root: "/x/Samples", folders: ["Cobalt Samples Vol 1"]), "Cobalt")
        // "Vendor - Product" pack names.
        XCTAssertEqual(Vendors.guess(root: "/x/Samples", folders: ["Delta Audio - Big Kicks", "Kicks"]), "Delta Audio")
        XCTAssertNil(Vendors.guess(root: "/x/Samples", folders: ["Random", "Kicks"]))
    }

    func testOldLibraryFileDecodesWithoutVendors() throws {
        let json = #"{"roots":["/a"],"items":{}}"#.data(using: .utf8)!
        let data = try JSONDecoder().decode(LibraryData.self, from: json)
        XCTAssertEqual(data.roots, ["/a"])
        XCTAssertTrue(data.vendors.isEmpty)
    }
}

/// Invented vendor list shared by tests, so no real company names appear in fixtures.
enum TestVendors {
    static let keywords: [(String, String)] = [
        ("acme", "Acme Audio"), ("bolt", "Bolt Drums"), ("cobalt", "Cobalt"),
    ]
}
