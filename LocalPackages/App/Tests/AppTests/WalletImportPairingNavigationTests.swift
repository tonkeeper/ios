@testable import App
import UIKit
import XCTest

@MainActor
final class WalletImportPairingNavigationTests: XCTestCase {
    func testPersistenceCompletionDuringDismissalDoesNotDependOnASecondDismissCompletion() {
        let navigationController = NavigationProbe()
        navigationController.presenter = UIViewController()
        navigationController.isDismissing = true
        var completions = 0

        WalletImportPairingNavigation.dismiss(navigationController) { completions += 1 }

        XCTAssertEqual(completions, 1)
        XCTAssertEqual(navigationController.dismissals, 0)
    }

    func testPresentedNavigationIsDismissedBeforeCompletingTheImport() {
        let navigationController = NavigationProbe()
        navigationController.presenter = UIViewController()
        var completions = 0

        WalletImportPairingNavigation.dismiss(navigationController) {
            XCTAssertEqual(navigationController.dismissals, 1)
            completions += 1
        }

        XCTAssertEqual(completions, 1)
    }

    func testAlreadyDismissedOrReleasedNavigationStillCompletesTheImport() {
        let navigationController = NavigationProbe()
        var completions = 0

        WalletImportPairingNavigation.dismiss(navigationController) { completions += 1 }
        WalletImportPairingNavigation.dismiss(nil) { completions += 1 }

        XCTAssertEqual(completions, 2)
        XCTAssertEqual(navigationController.dismissals, 0)
    }
}

private final class NavigationProbe: UINavigationController {
    var presenter: UIViewController?
    var isDismissing = false
    private(set) var dismissals = 0

    override var presentingViewController: UIViewController? {
        presenter
    }

    override var isBeingDismissed: Bool {
        isDismissing
    }

    override func dismiss(animated: Bool, completion: (() -> Void)? = nil) {
        dismissals += 1
        if !isDismissing { completion?() }
    }
}
