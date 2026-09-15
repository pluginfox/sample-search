import XCTest

/// Mirrors UpdateChecker.isNewer (app target has no test bundle); keep the two in sync.
final class VersionCompareTests: XCTestCase {
    func isNewer(_ candidate: String, than current: String) -> Bool {
        func parts(_ s: String) -> [Int] {
            s.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
                .split(whereSeparator: { $0 == "." || $0 == "-" })
                .map { Int($0.prefix { $0.isNumber }) ?? 0 }
        }
        let a = parts(candidate), b = parts(current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    func testCompare() {
        XCTAssertTrue(isNewer("v0.3.0", than: "0.2.0"))
        XCTAssertTrue(isNewer("1.0", than: "0.9.9"))
        XCTAssertTrue(isNewer("v0.2.1", than: "0.2"))
        XCTAssertFalse(isNewer("v0.2.0", than: "0.2.0"))
        XCTAssertFalse(isNewer("0.1.9", than: "0.2.0"))
        XCTAssertFalse(isNewer("v0.2", than: "0.2.0"))
    }
}
