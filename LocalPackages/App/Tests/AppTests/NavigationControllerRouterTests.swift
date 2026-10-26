import TKCoordinator
import UIKit
import XCTest

@MainActor
final class NavigationControllerRouterTests: XCTestCase {
    /// A Live Activity tap pops the screen it was on and pushes a flow in the same turn: UIKit queues
    /// that push, and the pop's didShow arrives before the flow is on the stack.
    func test_pushQueuedBehindAnotherTransitionIsNotTakenForPop() {
        let root = UIViewController()
        let navigationController = QueueingNavigationController(rootViewController: root)
        let router = NavigationControllerRouter(rootViewController: navigationController)
        let flow = UIViewController()
        var popCount = 0

        navigationController.queuesPushes = true
        router.push(viewController: flow, onPopClosures: { popCount += 1 })
        router.navigationController(navigationController, didShow: root, animated: false)
        XCTAssertEqual(popCount, 0)

        navigationController.performQueuedPushes()
        router.navigationController(navigationController, didShow: flow, animated: true)
        XCTAssertEqual(popCount, 0)

        navigationController.popViewController(animated: false)
        router.navigationController(navigationController, didShow: root, animated: false)
        XCTAssertEqual(popCount, 1)
    }

    func test_popToRootReportsEveryPoppedScreen() {
        let root = UIViewController()
        let navigationController = QueueingNavigationController(rootViewController: root)
        let router = NavigationControllerRouter(rootViewController: navigationController)
        var popped: [String] = []

        router.push(viewController: UIViewController(), animated: false, onPopClosures: { popped.append("first") })
        router.push(viewController: UIViewController(), animated: false, onPopClosures: { popped.append("second") })
        navigationController.popToRootViewController(animated: false)
        router.navigationController(navigationController, didShow: root, animated: false)

        XCTAssertEqual(Set(popped), ["first", "second"])
    }
}

/// Holds pushes back the way UIKit does while another transition is running.
private final class QueueingNavigationController: UINavigationController {
    var queuesPushes = false
    private var queuedPushes: [UIViewController] = []

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        guard queuesPushes else {
            super.pushViewController(viewController, animated: false)
            return
        }
        queuedPushes.append(viewController)
    }

    func performQueuedPushes() {
        queuesPushes = false
        queuedPushes.forEach { super.pushViewController($0, animated: false) }
        queuedPushes = []
    }
}
