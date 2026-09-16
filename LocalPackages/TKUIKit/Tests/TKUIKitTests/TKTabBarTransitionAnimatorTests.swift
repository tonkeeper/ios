@testable import TKUIKit
import XCTest

@MainActor
final class TKTabBarTransitionAnimatorTests: XCTestCase {
    func testHigherIndexBringsTheNextTabInFromTheRight() throws {
        let animator = try XCTUnwrap(TKTabBarTransitionAnimator(fromIndex: 1, toIndex: 2))

        XCTAssertEqual(animator.direction, .forward)
        XCTAssertGreaterThan(animator.direction.incomingStartOffset, 0)
        XCTAssertLessThan(animator.direction.outgoingEndOffset, 0)
    }

    func testLowerIndexBringsThePreviousTabInFromTheLeft() throws {
        let animator = try XCTUnwrap(TKTabBarTransitionAnimator(fromIndex: 2, toIndex: 1))

        XCTAssertEqual(animator.direction, .backward)
        XCTAssertLessThan(animator.direction.incomingStartOffset, 0)
        XCTAssertGreaterThan(animator.direction.outgoingEndOffset, 0)
    }

    func testBothTabsTravelTheSameWay() {
        for direction in [TKTabBarTransitionAnimator.Direction.forward, .backward] {
            XCTAssertEqual(direction.incomingStartOffset, -direction.outgoingEndOffset)
            XCTAssertNotEqual(direction.incomingStartOffset, 0)
        }
    }

    func testSkippedTabsDoNotStretchTheSlide() throws {
        let adjacent = try XCTUnwrap(TKTabBarTransitionAnimator(fromIndex: 0, toIndex: 1))
        let distant = try XCTUnwrap(TKTabBarTransitionAnimator(fromIndex: 0, toIndex: 2))

        XCTAssertEqual(adjacent.direction, distant.direction)
    }

    func testReselectingTheCurrentTabHasNoTransition() {
        XCTAssertNil(TKTabBarTransitionAnimator(fromIndex: 1, toIndex: 1))
    }
}
