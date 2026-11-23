@testable import App
import UIKit
import XCTest

@MainActor
final class LedgerNetworksViewControllerTests: XCTestCase {
    func testLeavingForSettingsKeepsItsBarHidden() async throws {
        let navigationController = UINavigationController(rootViewController: UIViewController())
        navigationController.setNavigationBarHidden(true, animated: false)
        let window = try await show(navigationController)
        defer { window.isHidden = true }

        navigationController.pushViewController(networks(), animated: false)
        try await settle()
        navigationController.popViewController(animated: false)
        try await settle()

        XCTAssertTrue(navigationController.isNavigationBarHidden)
    }

    func testLeavingForAScreenWithoutAHeaderBringsBackTheBarItHid() async throws {
        let navigationController = UINavigationController(rootViewController: networks())
        let window = try await show(navigationController)
        defer { window.isHidden = true }
        XCTAssertTrue(navigationController.isNavigationBarHidden)

        navigationController.pushViewController(UIViewController(), animated: false)
        try await settle()

        XCTAssertFalse(navigationController.isNavigationBarHidden)
    }

    private func networks() -> LedgerNetworksViewController {
        LedgerNetworksViewController(viewModel: LedgerNetworksViewModel(
            title: "Networks",
            description: "Choose networks",
            chains: [.ton, .tron],
            preselectedChains: []
        ))
    }

    private func show(_ viewController: UIViewController) async throws -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        try await settle()
        return window
    }

    private func settle() async throws {
        try await Task.sleep(nanoseconds: 100_000_000)
    }
}
