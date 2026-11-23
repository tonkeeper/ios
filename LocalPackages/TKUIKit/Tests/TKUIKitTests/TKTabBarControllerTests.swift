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

        XCTAssertEqual(controller.style, .custom)
        XCTAssertTrue(controller.tabBar is TKTabBar)
        XCTAssertNil(tab.tabBarItem.title)
        XCTAssertNotNil(controller.tabBarItemView(at: 0))
    }

    func testLiquidGlassInstallsTheSystemTabBarOnIOS26() throws {
        guard #available(iOS 26.0, *) else { throw XCTSkip("Liquid glass needs iOS 26") }
        let controller = TKTabBarController(isLiquidGlassEnabled: true)
        let tab = UIViewController()
        tab.tabBarItem = UITabBarItem(title: "Wallet", image: nil, tag: 0)
        controller.setViewControllers([tab], animated: false)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.layoutIfNeeded()

        XCTAssertEqual(controller.style, .systemHorizontal)
        XCTAssertFalse(controller.tabBar is TKTabBar)
        XCTAssertEqual(tab.tabBarItem.title, "Wallet")
        XCTAssertNil(controller.tabBarIconContainer(at: 0))
    }
}
