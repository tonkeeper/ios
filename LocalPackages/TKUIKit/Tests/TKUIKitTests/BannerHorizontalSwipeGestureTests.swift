@testable import TKUIKit
import UIKit
import XCTest

@MainActor
final class BannerHorizontalSwipeGestureTests: XCTestCase {
    func testHorizontalPullsBeginInBothDirections() {
        for x: CGFloat in [-20, 20] {
            XCTAssertTrue(shouldBegin(translation: CGPoint(x: x, y: 3)))
        }
    }

    func testVerticalPullsFailBeforeRecognizing() {
        for y: CGFloat in [-20, 20] {
            XCTAssertFalse(shouldBegin(translation: CGPoint(x: 3, y: y)))
        }
    }

    func testEqualDiagonalMovementDefersToScrolling() {
        for x: CGFloat in [-20, 20] {
            for y: CGFloat in [-20, 20] {
                XCTAssertFalse(shouldBegin(translation: CGPoint(x: x, y: y)))
            }
        }
    }

    func testStationaryTouchDoesNotBeginSwipe() {
        XCTAssertFalse(shouldBegin(translation: .zero))
    }

    private func shouldBegin(translation: CGPoint) -> Bool {
        let recognizer = PanGestureRecognizerStub(translation: translation)
        return recognizer.delegate?.gestureRecognizerShouldBegin?(recognizer) ?? true
    }
}

private final class PanGestureRecognizerStub: BannerHorizontalPanGestureRecognizer {
    private let offset: CGPoint

    init(translation: CGPoint) {
        offset = translation
        super.init()
    }

    override func translation(in view: UIView?) -> CGPoint {
        offset
    }
}
