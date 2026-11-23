import SwiftUI
@testable import TKUIKit
import XCTest

@MainActor
final class TKBottomSheetScrollHostingControllerTests: XCTestCase {
    private var window: UIWindow!

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    func testWarningGrowthAndRemovalNotifySheetAndUpdateScrollableHeight() {
        let state = ContentState()
        let controller = TKBottomSheetScrollHostingController(title: "Auto close", subtitle: nil, liveSubtitle: nil) {
            TestContent(state: state)
        }
        var heightUpdates = 0
        controller.didUpdateHeight = { heightUpdates += 1 }
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 300))
        window.rootViewController = controller
        let initialHeight = controller.calculateHeight(withWidth: 390)
        window.makeKeyAndVisible()
        render(controller)
        let initialUpdates = heightUpdates
        render(controller)
        XCTAssertEqual(heightUpdates, initialUpdates)
        state.warning = String(repeating: "Ликвидация наступит раньше. Установите стоп-лосс выше. ", count: 6)
        render(controller)
        XCTAssertGreaterThan(heightUpdates, initialUpdates)
        let expandedHeight = controller.calculateHeight(withWidth: 390)
        controller.view.layoutIfNeeded()
        XCTAssertGreaterThan(expandedHeight, controller.scrollView.bounds.height)
        XCTAssertEqual(controller.scrollView.contentSize.height, expandedHeight, accuracy: 1)

        let expandedUpdates = heightUpdates
        state.warning = nil
        render(controller)
        XCTAssertGreaterThan(heightUpdates, expandedUpdates)
        XCTAssertEqual(controller.calculateHeight(withWidth: 390), initialHeight, accuracy: 1)
        controller.view.layoutIfNeeded()
        XCTAssertEqual(controller.scrollView.contentSize.height, initialHeight, accuracy: 1)
    }

    private func render(_ controller: UIViewController) {
        controller.view.layoutIfNeeded()
        for child in controller.children {
            child.view.setNeedsLayout()
            child.view.layoutIfNeeded()
        }
    }
}

@MainActor
private final class ContentState: ObservableObject {
    @Published var warning: String?
}

private struct TestContent: View {
    @ObservedObject var state: ContentState

    var body: some View {
        VStack(spacing: 16) {
            Text("Take Profit")
            Color.clear.frame(height: 100)
            if let warning = state.warning {
                Text(warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Set").frame(height: 56)
        }
    }
}
