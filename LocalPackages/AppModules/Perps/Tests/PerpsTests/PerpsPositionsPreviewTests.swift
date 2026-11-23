@testable import Perps
import PerpsModels
import XCTest

final class PerpsPositionsPreviewTests: XCTestCase {
    func test_showsTheThreeNearestToLiquidation_whicheverSide_andTheRestCollapse() {
        let positions = [
            position(1, distance: 40),
            position(2, distance: -5, side: .short),
            position(3, distance: nil),
            position(4, distance: 12),
            position(5, distance: 8),
        ]

        let preview = preview(positions)

        XCTAssertEqual(preview.rows.map(\.id), [2, 5, 4])
        XCTAssertEqual(preview.more?.iconURLs, [url(1), url(3)])
    }

    func test_tiesAndMissingDistances_keepAStableMarketOrder() {
        let positions = [position(9, distance: nil), position(7, distance: 3), position(8, distance: 3), position(6, distance: nil)]

        XCTAssertEqual(preview(positions, limit: 4).rows.map(\.id), [7, 8, 6, 9])
    }

    func test_noMoreRow_untilAFourthPosition() {
        XCTAssertNil(preview((1 ... 3).map { position($0, distance: Double($0)) }).more)
        XCTAssertEqual(preview((1 ... 4).map { position($0, distance: Double($0)) }).more?.iconURLs, [url(4)])
    }

    func test_perpsList_keepsTheBackendOrder() {
        let positions = [position(9, distance: 30), position(2, distance: 1), position(5, distance: nil)]

        let rows = PerpsPositionRowMapping.rows(from: positions, format: .test, iconURL: url)

        XCTAssertEqual(rows.map(\.id), [9, 2, 5])
    }

    private func preview(_ positions: [PerpsPositionSummary], limit: Int = 3) -> PerpsPositionsPreview {
        PerpsPositionRowMapping.preview(from: positions, limit: limit, format: .test, iconURL: url)
    }

    private func url(_ marketId: Int64) -> URL? {
        URL(string: "https://example.com/\(marketId).png")
    }

    private func position(_ marketId: Int64, distance: Double?, side: PerpsTradeSide = .long) -> PerpsPositionSummary {
        PerpsPositionSummary(
            positionId: "lighter:\(marketId)",
            marketId: marketId,
            symbol: "M\(marketId)",
            side: side,
            baseSize: 1,
            notionalUsd: 100,
            marginUsd: 10,
            equityUsd: 10,
            leverage: 10,
            roiPercent: nil,
            entryPrice: 100,
            liquidationPrice: 90,
            unrealizedPnlUsd: 0,
            realizedPnlUsd: 0,
            fundingPaidUsd: 0,
            liquidationDistancePercent: distance
        )
    }
}
