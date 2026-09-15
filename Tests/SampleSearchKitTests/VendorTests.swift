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
        XCTAssertEqual(Vendors.guess(root: "/x/Vendor One Library", folders: ["Snares", "Snare 05"]), "Vendor One")
        XCTAssertEqual(Vendors.guess(root: "/x/Vendor Two Pack", folders: ["Snares"]), "Vendor Two")
        XCTAssertEqual(Vendors.guess(root: "/x/Samples", folders: ["Vendor Three Samples"]), "Vendor Three")
        // "Vendor - Product" pack names.
        XCTAssertEqual(Vendors.guess(root: "/x/Samples", folders: ["Vendor Four - Pack B", "Kicks"]), "Vendor Four")
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
        ("vendor one", "Vendor One"), ("vendor two", "Vendor Two"), ("vendor three", "Vendor Three"),
    ]
}
