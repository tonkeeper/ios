@testable import App
import UIKit
import XCTest

@MainActor
final class ModalFlowNavigationControllerTests: XCTestCase {
    func test_resolvesNavigationControllerFromSelectedTab() {
        let selectedNavigationController = UINavigationController()
        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [UIViewController(), selectedNavigationController]
        tabBarController.selectedIndex = 1

        XCTAssertTrue(
            modalFlowNavigationController(rootViewController: tabBarController) === selectedNavigationController
        )
    }

    func test_acceptsNavigationControllerAsRoot() {
        let navigationController = UINavigationController()

        XCTAssertTrue(
            modalFlowNavigationController(rootViewController: navigationController) === navigationController
        )
    }
}
