@testable import TKUIKit
import XCTest

@MainActor
final class TKTabBarControllerTests: XCTestCase {
    func testRegularPhoneInstallsTheCustomTabBar() {
        let controller = TKTabBarController()
        let tab = UIViewController()
        tab.tabBarItem = UITabBarItem(title: "Wallet", image: nil, tag: 0)
        controller.setViewControllers([tab], animated: false)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.layoutIfNeeded()

        XCTAssertTrue(controller.tabBar is TKTabBar)
        XCTAssertNil(tab.tabBarItem.title)
        XCTAssertNotNil(controller.tabBarItemView(at: 0))
    }
}
