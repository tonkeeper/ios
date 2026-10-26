@testable import TKUIKit
import UIKit
import XCTest

@MainActor
final class SwipeBackGestureTests: XCTestCase {
    func testEdgeOnlyScreenAllowsSwipeBackFromTheLeadingEdge() {
        let navigationController = makeNavigationController(pushing: EdgeOnlyViewController())

        XCTAssertTrue(navigationController.canBeginSwipeBackGesture(PanGestureRecognizerStub(startX: 12)))
    }

    func testEdgeOnlyScreenRejectsSwipeBackFromTheContent() {
        let navigationController = makeNavigationController(pushing: EdgeOnlyViewController())

        XCTAssertFalse(navigationController.canBeginSwipeBackGesture(PanGestureRecognizerStub(startX: 120)))
    }

    func testRegularScreenAllowsSwipeBackFromTheContent() {
        let navigationController = makeNavigationController(pushing: UIViewController())

        XCTAssertTrue(navigationController.canBeginSwipeBackGesture(PanGestureRecognizerStub(startX: 120)))
    }

    func testEdgeOnlyScreenKeepsSwipeBackOffWhileItIsDisabled() {
        let navigationController = makeNavigationController(pushing: EdgeOnlyViewController())
        navigationController.interactivePopGestureRecognizer?.isEnabled = false

        XCTAssertFalse(navigationController.canBeginSwipeBackGesture(PanGestureRecognizerStub(startX: 12)))
    }

    private func makeNavigationController(pushing viewController: UIViewController) -> UINavigationController {
        let navigationController = UINavigationController(rootViewController: UIViewController())
        navigationController.loadViewIfNeeded()
        navigationController.pushViewController(viewController, animated: false)
        return navigationController
    }
}

private final class EdgeOnlyViewController: UIViewController, TKEdgeSwipeBackOnly {}

private final class PanGestureRecognizerStub: UIPanGestureRecognizer {
    private let startX: CGFloat
    private let translationX: CGFloat = 30

    init(startX: CGFloat) {
        self.startX = startX
        super.init(target: nil, action: nil)
    }

    override func location(in view: UIView?) -> CGPoint {
        CGPoint(x: startX + translationX, y: 300)
    }

    override func translation(in view: UIView?) -> CGPoint {
        CGPoint(x: translationX, y: 0)
    }

    override func velocity(in view: UIView?) -> CGPoint {
        CGPoint(x: 500, y: 0)
    }
}
