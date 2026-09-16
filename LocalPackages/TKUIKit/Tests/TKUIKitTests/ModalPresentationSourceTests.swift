@testable import TKUIKit
import UIKit
import XCTest

@MainActor
final class ModalPresentationSourceTests: XCTestCase {
    private var window: UIWindow!
    private var rootViewController: UIViewController!

    override func setUp() {
        super.setUp()
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        rootViewController = UIViewController()
        window.rootViewController = rootViewController
        window.makeKeyAndVisible()
    }

    override func tearDown() {
        window.isHidden = true
        window = nil
        rootViewController = nil
        super.tearDown()
    }

    func test_withoutAModal_isTheWindowRoot() {
        let embedded = embedInRoot(UINavigationController(rootViewController: UIViewController()))

        XCTAssertIdentical(embedded.modalPresentationSourceViewController(), rootViewController)
    }

    /// The bug this exists for: a coordinator's router root presents nothing itself, so
    /// `topPresentedViewController()` hands back the controller under the sheet — and presenting
    /// from there is refused, because it forwards up to the window root the sheet already owns.
    func test_underAModal_isTheModalAndNotTheControllerItself() {
        let underTheModal = addToRootViewWithoutContainment(UINavigationController(rootViewController: UIViewController()))
        let modal = present(UIViewController(), from: rootViewController)

        XCTAssertIdentical(underTheModal.topPresentedViewController(), underTheModal)
        XCTAssertIdentical(underTheModal.modalPresentationSourceViewController(), modal)
    }

    func test_forTheModalItself_staysTheModal() {
        let modal = present(UIViewController(), from: rootViewController)

        XCTAssertIdentical(modal.modalPresentationSourceViewController(), modal)
    }

    func test_outsideAWindow_fallsBackToTheControllerItself() {
        let detached = UIViewController()

        XCTAssertIdentical(detached.modalPresentationSourceViewController(), detached)
    }
}

private extension ModalPresentationSourceTests {
    func embedInRoot<Controller: UIViewController>(_ controller: Controller) -> Controller {
        rootViewController.addChild(controller)
        rootViewController.view.addSubview(controller.view)
        controller.didMove(toParent: rootViewController)
        return controller
    }

    /// `presentedViewController` also reports what an *ancestor* presents, so a child of the root
    /// never has the nil the bug needs. Only a controller outside that containment chain — which is
    /// how the sheet reaches the window root from another branch — reproduces it.
    func addToRootViewWithoutContainment<Controller: UIViewController>(_ controller: Controller) -> Controller {
        rootViewController.view.addSubview(controller.view)
        return controller
    }

    /// The presentation lands synchronously, but its completion never runs: the test bundle has no
    /// window scene to drive the transition, so awaiting it hangs. For the same reason a second,
    /// stacked presentation never takes effect here, which is why there is no stacked-modal test.
    func present<Controller: UIViewController>(
        _ controller: Controller,
        from presenting: UIViewController
    ) -> Controller {
        presenting.present(controller, animated: false, completion: nil)
        return controller
    }
}
