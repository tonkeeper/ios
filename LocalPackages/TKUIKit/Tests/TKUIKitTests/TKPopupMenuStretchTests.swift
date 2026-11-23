@testable import TKUIKit
import XCTest

final class TKPopupMenuStretchTests: XCTestCase {
    private let size = CGSize(width: 220, height: 212)

    func test_theMenuStaysAsItIsWhileTheFingerIsOverIt() {
        XCTAssertEqual(TKPopupMenuView.stretchTransform(overshoot: .zero, size: size), .identity)
    }

    func test_aFingerBelowPullsTheMenuDownFromItsTopEdge() {
        let frame = leanedFrame(overshoot: CGPoint(x: 0, y: 200))

        XCTAssertGreaterThan(frame.minY, 0, "the menu moves after the finger")
        XCTAssertGreaterThan(frame.maxY - size.height, frame.minY, "and stretches towards it")
        XCTAssertGreaterThan(frame.minX, 0, "it narrows")
        XCTAssertEqual(frame.minX, size.width - frame.maxX, accuracy: 0.001, "on both sides")
        XCTAssertEqual(frame.width * frame.height, size.width * size.height, accuracy: 0.5, "keeping its area")
    }

    func test_aFingerAboveKeepsTheBottomEdgeNearlyInPlace() {
        let frame = leanedFrame(overshoot: CGPoint(x: 0, y: -200))

        XCTAssertLessThan(frame.minY, 0)
        XCTAssertLessThan(frame.maxY, size.height)
        XCTAssertGreaterThan(-frame.minY, size.height - frame.maxY, "the top edge goes further than the bottom one")
    }

    func test_aFingerOnTheLeftPullsTheMenuLeftFromItsRightEdge() {
        let frame = leanedFrame(overshoot: CGPoint(x: -150, y: 0))

        XCTAssertLessThan(frame.minX, 0)
        XCTAssertLessThan(frame.maxX, size.width)
        XCTAssertGreaterThan(-frame.minX, size.width - frame.maxX, "the left edge goes further than the right one")
        XCTAssertEqual(frame.minY, size.height - frame.maxY, accuracy: 0.001, "it narrows evenly top and bottom")
    }

    func test_thePullGrowsWithTheDistanceAndLevelsOff() throws {
        let heights = [50, 100, 200, 400, 5000].map { leanedFrame(overshoot: CGPoint(x: 0, y: $0)).height }

        XCTAssertEqual(heights, heights.sorted())
        XCTAssertEqual(Set(heights).count, heights.count)
        XCTAssertLessThan(try XCTUnwrap(heights.last), size.height * 1.3)
    }

    /// The menu's frame on screen: a view's transform applies around its centre.
    private func leanedFrame(overshoot: CGPoint) -> CGRect {
        let transform = TKPopupMenuView.stretchTransform(overshoot: overshoot, size: size)
        return CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
            .applying(transform)
            .offsetBy(dx: size.width / 2, dy: size.height / 2)
    }
}
