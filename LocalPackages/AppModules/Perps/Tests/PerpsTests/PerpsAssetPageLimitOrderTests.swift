@testable import Perps
import PerpsModels
import TKLocalize
import XCTest

final class PerpsAssetPageLimitOrderTests: XCTestCase {
    func test_caption_showsExpiryDate() {
        let expiresAt: Int64 = 1_793_750_400
        let order = PerpsAssetPageViewModel.makeLimitOrder(summary(expiresAtSeconds: expiresAt), format: .test)

        XCTAssertEqual(
            order.captionText,
            TKLocales.Perps.Asset.limitPriceExpires(PerpsFormatting.test.dayMonth(Date(timeIntervalSince1970: TimeInterval(expiresAt))))
        )
    }

    func test_caption_withoutExpiry_fallsBackToLimitPrice() {
        let order = PerpsAssetPageViewModel.makeLimitOrder(summary(expiresAtSeconds: 0), format: .test)

        XCTAssertEqual(order.captionText, TKLocales.Perps.Asset.limitPrice)
    }

    func test_limitOrder_showsTheLegsPlacedWithIt() {
        let order = PerpsAssetPageViewModel.makeLimitOrder(summary(expiresAtSeconds: 0, autoCloseLegs: [
            PerpsTriggerOrderSummary(orderIndex: 2, kind: .takeProfit, side: .short, triggerPrice: 70000, baseAmount: 0),
            PerpsTriggerOrderSummary(orderIndex: 3, kind: .stopLoss, side: .short, triggerPrice: 61800, baseAmount: 0),
        ]), format: .test)

        XCTAssertEqual(order.takeProfitText, PerpsFormatting.test.price(70000))
        XCTAssertEqual(order.stopLossText, PerpsFormatting.test.price(61800))
    }

    func test_limitOrder_withoutLegs_showsNoAutoClose() {
        let order = PerpsAssetPageViewModel.makeLimitOrder(summary(expiresAtSeconds: 0), format: .test)

        XCTAssertNil(order.takeProfitText)
        XCTAssertNil(order.stopLossText)
    }

    func test_actions_restingLimitOrderWithoutPosition_offerEditCancel() {
        XCTAssertEqual(actions(lifecycle: .flat, cancelEnabled: true), .editCancelLimitOrder(orderIndex: 1, editEnabled: true, cancelEnabled: true))
        XCTAssertEqual(actions(lifecycle: .flat, cancelEnabled: false), .editCancelLimitOrder(orderIndex: 1, editEnabled: false, cancelEnabled: false))
        XCTAssertEqual(actions(lifecycle: .flat, cancelEnabled: true, isLimitOrderBusy: true), .editCancelLimitOrder(orderIndex: 1, editEnabled: false, cancelEnabled: false))
    }

    func test_actions_restingLimitOrderBelowMarketMinimum_offersOnlyCancel() {
        XCTAssertEqual(
            actions(lifecycle: .flat, cancelEnabled: true, isBelowMarketMinimum: true),
            .editCancelLimitOrder(orderIndex: 1, editEnabled: false, cancelEnabled: true)
        )
    }

    func test_actions_restingLimitOrderWithOpenPosition_keepEditCashOut() {
        XCTAssertEqual(actions(lifecycle: .open(position()), cancelEnabled: true), .editCashOut(editEnabled: true, cashOutEnabled: true))
    }

    func test_changeToast_namesTheChangeInsteadOfPlacing() {
        XCTAssertEqual(PerpsAssetPageViewModel.limitOrderChangeToastText(.cancel, isDone: false), TKLocales.Perps.Toast.orderCancelling)
        XCTAssertEqual(PerpsAssetPageViewModel.limitOrderChangeToastText(.cancel, isDone: true), TKLocales.Perps.Toast.orderCancelled)
        XCTAssertEqual(PerpsAssetPageViewModel.limitOrderChangeToastText(.modify, isDone: false), TKLocales.Perps.Toast.orderUpdating)
        XCTAssertEqual(PerpsAssetPageViewModel.limitOrderChangeToastText(.modify, isDone: true), TKLocales.Perps.Toast.orderUpdated)
    }

    func test_changeReview_showsTheSizeItSignsAndTheLegsConfirmRemoves() {
        let review = PerpsLimitOrderChangeReview(
            order: PerpsLimitOrderSummary(orderIndex: 7, clientOrderIndex: 7, side: .long, limitPrice: 1900, remainingBaseAmount: 0.4),
            kind: .modify,
            limitPrice: 2200,
            baseAmount: 0.5
        )
        let legs = [
            PerpsTriggerOrderSummary(orderIndex: 2, kind: .takeProfit, side: .short, triggerPrice: 2100, baseAmount: 0),
            PerpsTriggerOrderSummary(orderIndex: 3, kind: .stopLoss, side: .short, triggerPrice: 1850, baseAmount: 0),
        ]
        let size = "\(TKLocales.Perps.Confirm.size) \(PerpsFormatting.test.token(0.5, symbol: "ETH", decimals: 3))"
        let price = "\(TKLocales.Perps.Order.price) \(PerpsFormatting.test.price(1900)) → \(PerpsFormatting.test.price(2200))"

        let text = PerpsAssetPageViewModel.limitOrderChangeReviewText(review, symbol: "ETH", sizeDecimals: 3, removedLegs: legs, format: .test)
        let withoutLegs = PerpsAssetPageViewModel.limitOrderChangeReviewText(review, symbol: "ETH", sizeDecimals: 3, removedLegs: [], format: .test)

        XCTAssertEqual(text.title, PerpsAssetPageViewModel.toastPosition(symbol: "ETH", side: .long))
        XCTAssertEqual(text.message, [
            size,
            price,
            TKLocales.Perps.SetLimitPrice.takeProfitRemoved,
            TKLocales.Perps.SetLimitPrice.stopLossRemoved,
        ].joined(separator: "\n"))
        XCTAssertEqual(withoutLegs.message, [size, price].joined(separator: "\n"))
    }

    private func actions(
        lifecycle: PerpsMarketLifecycle,
        cancelEnabled: Bool,
        isLimitOrderBusy: Bool = false,
        isBelowMarketMinimum: Bool = false
    ) -> PerpsAssetPageActions {
        PerpsAssetPageViewModel.actions(
            for: lifecycle,
            snapshot: snapshot(),
            restingLimitOrder: summary(expiresAtSeconds: 0, isBelowMarketMinimum: isBelowMarketMinimum),
            flags: PerpsTradingFlags(
                openEnabled: true,
                closeEnabled: true,
                cancelEnabled: cancelEnabled,
                addMarginEnabled: true,
                removeMarginEnabled: true,
                autoCloseEnabled: true
            ),
            isAccountActive: true,
            isLimitOrderBusy: isLimitOrderBusy
        )
    }

    private func snapshot() -> PerpsAssetMarketSnapshot {
        PerpsAssetMarketSnapshot(
            marketId: 1, symbol: "BTC", displayName: "BTC",
            status: "active", maxLeverage: 40, priceDecimals: 2,
            sizeDecimals: 2,
            price: 66141, priceChangePercent: 4.37, priceChangeAmount: 100,
            volume24h: 2_360_000_000, openInterest: 1_700_000_000, fundingRatePercent: nil, about: nil,
            openEnabled: true
        )
    }

    private func position() -> PerpsPositionSummary {
        PerpsPositionSummary(
            positionId: "lighter:1",
            marketId: 1, symbol: "BTC", side: .long, baseSize: 1,
            notionalUsd: 540, marginUsd: 20, equityUsd: 20.5,
            leverage: 27, roiPercent: 2.5, entryPrice: 66541.7,
            liquidationPrice: 64141.75, unrealizedPnlUsd: 0.5,
            realizedPnlUsd: 0, fundingPaidUsd: 0,
            liquidationDistancePercent: -3.02
        )
    }

    private func summary(
        expiresAtSeconds: Int64,
        autoCloseLegs: [PerpsTriggerOrderSummary] = [],
        isBelowMarketMinimum: Bool = false
    ) -> PerpsLimitOrderSummary {
        var order = PerpsLimitOrderSummary(
            orderIndex: 1,
            clientOrderIndex: 10,
            side: .long,
            limitPrice: 64000,
            remainingBaseAmount: 1,
            expiresAtSeconds: expiresAtSeconds,
            autoCloseLegs: autoCloseLegs
        )
        order.isBelowMarketMinimum = isBelowMarketMinimum
        return order
    }
}
