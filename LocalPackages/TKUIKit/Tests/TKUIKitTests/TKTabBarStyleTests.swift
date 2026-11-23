@testable import TKUIKit
import XCTest

final class TKTabBarStyleTests: XCTestCase {
    func testRegularPhoneKeepsTheCustomTabBar() {
        XCTAssertEqual(resolve(edge: false, keepsSystemBar: false, liquidGlass: false), .custom)
    }

    func testRegularPhoneWithLiquidGlassUsesTheSystemHorizontalBar() {
        XCTAssertEqual(resolve(edge: false, keepsSystemBar: false, liquidGlass: true), .systemHorizontal)
    }

    func testDuoWithAVerticalBarUsesTheSystemVerticalBar() {
        XCTAssertEqual(resolve(edge: true, keepsSystemBar: true, liquidGlass: false), .systemVertical)
        XCTAssertEqual(resolve(edge: true, keepsSystemBar: true, liquidGlass: true), .systemVertical)
    }

    func testDuoWithAHorizontalBarUsesTheSystemHorizontalBar() {
        XCTAssertEqual(resolve(edge: false, keepsSystemBar: true, liquidGlass: false), .systemHorizontal)
        XCTAssertEqual(resolve(edge: false, keepsSystemBar: true, liquidGlass: true), .systemHorizontal)
    }

    private func resolve(edge: Bool, keepsSystemBar: Bool, liquidGlass: Bool) -> TKTabBarStyle {
        TKTabBarStyle.resolve(
            verticalBarEdgeIsSpecified: edge,
            keepsSystemBar: keepsSystemBar,
            liquidGlassEnabled: liquidGlass
        )
    }
}
