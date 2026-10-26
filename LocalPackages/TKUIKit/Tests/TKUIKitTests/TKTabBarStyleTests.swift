@testable import TKUIKit
import XCTest

final class TKTabBarStyleTests: XCTestCase {
    func testRegularPhoneKeepsTheCustomTabBar() {
        XCTAssertEqual(
            TKTabBarStyle.resolve(verticalBarEdgeIsSpecified: false, systemTabBarLocked: false),
            .custom
        )
    }

    func testDuoUsesTheSystemTabBar() {
        XCTAssertEqual(
            TKTabBarStyle.resolve(verticalBarEdgeIsSpecified: true, systemTabBarLocked: false),
            .system
        )
    }

    func testDuoStaysOnTheSystemTabBarWhenTheEdgeGoesAway() {
        XCTAssertEqual(
            TKTabBarStyle.resolve(verticalBarEdgeIsSpecified: false, systemTabBarLocked: true),
            .system
        )
    }
}
