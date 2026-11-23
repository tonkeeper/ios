@testable import Perps
import TKUIKit
import UIKit
import XCTest

@MainActor
final class PerpsFundingAssetSheetLayoutTests: XCTestCase {
    /// Row heights follow the simulator's font metrics, so the test checks proportions, not points.
    func testShortPickerMeasuresItsRowsInsteadOfTheScreen() {
        let two = contentHeight(assetCount: 2)
        let three = contentHeight(assetCount: 3)
        let four = contentHeight(assetCount: 4)

        XCTAssertLessThan(four, 844 / 2)
        XCTAssertGreaterThan(three - two, 0)
        XCTAssertEqual(four - three, three - two, accuracy: 1)
    }

    func testLongPickerReportsContentBeyondTheViewport() {
        XCTAssertGreaterThan(contentHeight(assetCount: 16), 844)
    }

    private func contentHeight(assetCount: Int) -> CGFloat {
        let assets = (0 ..< assetCount).map {
            PerpsFundingAssetRow(assetId: "asset-\($0)", symbol: "USDC", network: .ethereum, iconURL: nil, balanceText: nil)
        }
        let controller = TKBottomSheetScrollHostingController(
            title: "Choose asset",
            subtitle: nil,
            liveSubtitle: nil
        ) {
            PerpsFundingAssetSheetView(assets: assets, selected: assets[0], onSelect: { _ in })
        }
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        controller.view.layoutIfNeeded()
        return controller.calculateHeight(withWidth: 390)
    }
}
