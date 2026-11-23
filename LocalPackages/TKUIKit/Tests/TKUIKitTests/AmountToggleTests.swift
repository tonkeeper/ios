@testable import TKUIKit
import XCTest

final class AmountToggleTests: XCTestCase {
    func testTogglingBackRestoresTheCapturedValue() {
        var toggle = AmountToggle<String>()

        XCTAssertEqual(toggle.toggle("0.3", converted: "1.49"), "1.49")
        XCTAssertEqual(toggle.toggle("1.49", converted: "0.298"), "0.3")
        XCTAssertEqual(toggle.toggle("0.3", converted: "1.49"), "1.49")
    }

    func testResetConvertsAfresh() {
        var toggle = AmountToggle<String>()
        _ = toggle.toggle("0.3", converted: "1.49")

        toggle.reset()
        XCTAssertNil(toggle.counterpart)
        XCTAssertEqual(toggle.toggle("2", converted: "0.4"), "0.4")
    }
}
