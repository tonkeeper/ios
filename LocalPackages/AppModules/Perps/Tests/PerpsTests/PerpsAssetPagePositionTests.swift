@testable import Perps
import PerpsModels
import XCTest

final class PerpsAssetPagePositionTests: XCTestCase {
    private let hidden = PerpsFormatting(amounts: PerpsTestAmountFormatting()) { "* * *" }

    func test_triggerOrderPercent_isTheBackendProjection_whenTheLegCarriesOne() {
        let order = PerpsAssetPageViewModel.makeTriggerOrder(
            triggerOrder(triggerPrice: 104.3339, projectedROIPercent: 60.93),
            position: position(),
            format: .test
        )

        XCTAssertEqual(order.percentText, PerpsFormatting.test.signedPercent(60.93))
    }

    func test_triggerOrderPercent_isCutTowardZero_whenCountedHere() {
        let order = PerpsAssetPageViewModel.makeTriggerOrder(
            triggerOrder(triggerPrice: 104.3339, projectedROIPercent: nil),
            position: position(),
            format: .test
        )

        XCTAssertEqual(order.percentText, PerpsFormatting.test.signedPercent(43.33))
    }

    func test_triggerOrderValue_followsTheLivePositionSize_notTheLegSizeAtCreation() {
        let order = PerpsAssetPageViewModel.makeTriggerOrder(
            triggerOrder(triggerPrice: 110, projectedROIPercent: nil),
            position: position(baseSize: 2.5),
            format: .test
        )

        XCTAssertEqual(order.valueText, PerpsFormatting.test.signedBalance(25))
    }

    func test_hiddenBalances_maskThePositionAmountsAndDropThePnlColor() {
        let card = PerpsAssetPageViewModel.makePosition(position(), markPrice: 101, sizeDecimals: 2, isPending: false, format: hidden)

        XCTAssertEqual(card.valueText, "* * *")
        XCTAssertEqual(card.pnlText, "* * *")
        XCTAssertNil(card.pnlPercentText)
        XCTAssertNil(card.isPnlPositive)
        XCTAssertEqual(card.sizeUsdText, "* * *")
        XCTAssertEqual(card.sizeTokenText, "* * *")
        XCTAssertEqual(card.fundingText, "* * *")
        XCTAssertEqual(card.entryText, PerpsFormatting.test.price(100))
        XCTAssertEqual(card.liquidationText, PerpsFormatting.test.price(90))
    }

    func test_hiddenBalances_maskTheTriggerOrderOutcome() {
        let order = PerpsAssetPageViewModel.makeTriggerOrder(
            triggerOrder(triggerPrice: 104.3339, projectedROIPercent: 60.93),
            position: position(),
            format: hidden
        )

        XCTAssertEqual(order.valueText, "* * *")
        XCTAssertNil(order.percentText)
        XCTAssertEqual(order.priceText, PerpsFormatting.test.price(104.3339))
    }

    private func position(baseSize: Double = 1) -> PerpsPositionSummary {
        PerpsPositionSummary(
            positionId: "lighter:1",
            marketId: 1, symbol: "BTC", side: .long, baseSize: baseSize,
            notionalUsd: 100, marginUsd: 10, equityUsd: 10.5,
            leverage: 10, roiPercent: 5, entryPrice: 100,
            liquidationPrice: 90, unrealizedPnlUsd: 0.5,
            realizedPnlUsd: 0, fundingPaidUsd: -0.1,
            liquidationDistancePercent: -10
        )
    }

    private func triggerOrder(triggerPrice: Double, projectedROIPercent: Double?) -> PerpsTriggerOrderSummary {
        PerpsTriggerOrderSummary(
            orderIndex: 7,
            kind: .takeProfit,
            side: .short,
            triggerPrice: triggerPrice,
            baseAmount: 1,
            projectedROIPercent: projectedROIPercent
        )
    }
}
