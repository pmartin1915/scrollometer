import XCTest
@testable import ScrollCore

final class ScrollCoreTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(ScrollCoreVersion.current, "0.1.0")
    }
}
