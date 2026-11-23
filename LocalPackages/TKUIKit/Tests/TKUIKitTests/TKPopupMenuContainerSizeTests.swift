@testable import TKUIKit
import XCTest

@MainActor
final class TKPopupMenuContainerSizeTests: XCTestCase {
    func test_aResizedContainerReportsOnce() {
        var reports = 0
        let (window, menu) = makeShownMenu(onChange: { reports += 1 })

        window.frame.size = CGSize(width: 590, height: 820)
        window.layoutIfNeeded()
        XCTAssertEqual(reports, 1)

        window.frame.size = CGSize(width: 410, height: 1180)
        window.layoutIfNeeded()
        XCTAssertEqual(reports, 1)
        XCTAssertEqual(menu.view.bounds.size, window.bounds.size)
    }

    func test_aLayoutPassAtTheSameSizeReportsNothing() {
        var reports = 0
        let (window, menu) = makeShownMenu(onChange: { reports += 1 })

        menu.view.setNeedsLayout()
        window.layoutIfNeeded()

        XCTAssertEqual(reports, 0)
    }

    private func makeShownMenu(onChange: @escaping () -> Void) -> (UIWindow, TKPopupMenuViewController) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 410, height: 1180))
        let sourceView = UIView(frame: CGRect(x: 300, y: 40, width: 40, height: 40))
        window.addSubview(sourceView)

        let menu = TKPopupMenuViewController()
        menu.didChangeContainerSize = onChange
        window.addSubview(menu.view)
        menu.view.frame = window.bounds
        menu.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        menu.showMenu(
            items: [TKPopupMenuItem(title: "Refresh", icon: nil, selectionHandler: nil)],
            selectedIndex: nil,
            sourceView: sourceView,
            position: .bottomRight(inset: 8),
            minimumWidth: 0,
            maximumWidth: 300,
            duration: 0
        )
        window.layoutIfNeeded()
        return (window, menu)
    }
}
