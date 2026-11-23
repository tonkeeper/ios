@testable import TKUIKit
import XCTest

@MainActor
final class TKPopupMenuTrackingTests: XCTestCase {
    func test_theBandsBesideTheItemsPickTheirRows() {
        let menu = makeMenu()
        let stackWidth = menu.stackView.bounds.width

        XCTAssertEqual(menu.enabledItemIndex(at: CGPoint(x: -6, y: 24)), 0)
        XCTAssertEqual(menu.enabledItemIndex(at: CGPoint(x: stackWidth + 6, y: 72)), 1)
        XCTAssertNil(menu.enabledItemIndex(at: CGPoint(x: -14, y: 24)), "past the menu's side")
        XCTAssertNil(menu.enabledItemIndex(at: CGPoint(x: 40, y: -4)), "in the inset above the items")
    }

    func test_aDisabledItemIsNotPicked() {
        let menu = makeMenu(isSecondEnabled: false)

        XCTAssertNil(menu.enabledItemIndex(at: CGPoint(x: 40, y: 72)))
    }

    func test_aMenuOnItsWayOutPicksNothing() {
        var picks = 0
        let menu = makeMenu(onPick: { picks += 1 })

        menu.isUserInteractionEnabled = false
        menu.pickItem(at: 0)
        XCTAssertEqual(picks, 0)

        menu.isUserInteractionEnabled = true
        menu.pickItem(at: 0)
        XCTAssertEqual(picks, 1)
    }

    func test_aMenuClosedUnderTheFingerMarksNothing() {
        let menu = makeMenu()
        menu.highlightItem(at: 0)

        menu.prepareToHide()

        XCTAssertNil(menu.highlightedIndex)
        XCTAssertFalse(menu.isUserInteractionEnabled)
    }

    func test_aPickedItemStaysMarkedWhileTheMenuHides() {
        let menu = makeMenu()
        menu.highlightItem(at: 0)
        menu.pickItem(at: 0)

        menu.prepareToHide()

        XCTAssertEqual(menu.highlightedIndex, 0)
    }

    func test_glassWidensTheMenuByTheItemsSideInsets() {
        XCTAssertEqual(TKPopupMenuView(isLiquidGlass: true).itemsSideInsets, 20)
        XCTAssertEqual(TKPopupMenuView(isLiquidGlass: false).itemsSideInsets, 0)
    }

    private func makeMenu(isSecondEnabled: Bool = true, onPick: @escaping () -> Void = {}) -> TKPopupMenuView {
        let menu = TKPopupMenuView(isLiquidGlass: true)
        menu.items = [
            TKPopupMenuItemView.Model(
                title: "Add to favorites",
                value: nil,
                description: nil,
                icon: nil,
                leftIcon: nil,
                isSelectable: false,
                isEnabled: true,
                selectionHandler: onPick
            ),
            TKPopupMenuItemView.Model(
                title: "Hide",
                value: nil,
                description: nil,
                icon: nil,
                leftIcon: nil,
                isSelectable: false,
                isEnabled: isSecondEnabled
            ),
        ]
        menu.frame = CGRect(x: 0, y: 0, width: 220, height: 116)
        menu.layoutIfNeeded()
        return menu
    }
}
