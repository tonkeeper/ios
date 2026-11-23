@testable import Perps
import TKCoordinator
import UIKit
import XCTest

@MainActor
final class PerpsCoordinatorBackTests: XCTestCase {
    func testBackOnTheFirstScreenOfAPresentedFlowDismissesItAndFinishes() {
        let navigationController = PresentedNavigationRecorder()
        let perps = makePerps(on: navigationController)
        var finished = false
        perps.didFinish = { _ in finished = true }
        perps.start()

        tapBack(on: navigationController.viewControllers.first)

        XCTAssertTrue(navigationController.dismissed)
        XCTAssertTrue(finished)
        XCTAssertEqual(navigationController.viewControllers.count, 1)
    }

    func testBackOnTheFirstPerpsScreenInsideATabPopsIt() {
        let navigationController = PresentedNavigationRecorder(rootViewController: UIViewController())
        navigationController.isPresented = false
        let perps = makePerps(on: navigationController)
        perps.start()

        tapBack(on: navigationController.viewControllers.last)

        XCTAssertFalse(navigationController.dismissed)
        XCTAssertEqual(navigationController.viewControllers.count, 1)
    }

    func testThePerpsFlowIsOnTopOnlyWhileItIsNeitherCoveredNorLeft() {
        let navigationController = PresentedNavigationRecorder(rootViewController: UIViewController())
        navigationController.isPresented = false
        let perps = makePerps(on: navigationController)
        XCTAssertFalse(perps.isFlowOnTop)
        perps.start()
        XCTAssertTrue(perps.isFlowOnTop)

        navigationController.covering = UIViewController()
        XCTAssertFalse(perps.isFlowOnTop)
        navigationController.covering = nil

        navigationController.setViewControllers(Array(navigationController.viewControllers.prefix(1)), animated: false)
        XCTAssertFalse(perps.isFlowOnTop)
    }

    private func makePerps(on navigationController: UINavigationController) -> PerpsCoordinator {
        PerpsCoordinator(
            router: NavigationControllerRouter(rootViewController: navigationController),
            perpsAssembly: StubDependencies(),
            walletDependencies: PerpsWalletDependencies(
                accountStore: StubRootAccountStore(),
                tradingService: StubTradingService(),
                activateAccount: { _, _, _ in .canceled },
                signingPasscode: { _, _ in nil },
                recoverFunding: {},
                refreshFunding: {},
                makeDeposit: { _ in nil },
                makeHistory: { _, _, _, _, _ in nil },
                track: { _ in }
            )
        )
    }

    private func tapBack(on viewController: UIViewController?) {
        let viewModel = viewController.flatMap { Mirror(reflecting: $0).descendant("viewModel") } as? PerpsViewModel
        XCTAssertNotNil(viewModel)
        viewModel?.onBack?()
    }
}

private final class PresentedNavigationRecorder: UINavigationController {
    var isPresented = true
    var covering: UIViewController?
    private(set) var dismissed = false

    override var presentingViewController: UIViewController? {
        isPresented ? UIViewController() : nil
    }

    override var presentedViewController: UIViewController? {
        covering
    }

    override func dismiss(animated _: Bool, completion _: (() -> Void)? = nil) {
        dismissed = true
    }
}
