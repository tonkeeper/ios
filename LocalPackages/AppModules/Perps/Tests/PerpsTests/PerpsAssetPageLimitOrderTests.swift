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

    func test_actions_restingLimitOrderWithoutPosition_offerEditCancel() {
        XCTAssertEqual(actions(lifecycle: .flat, cancelEnabled: true), .editCancelLimitOrder(orderIndex: 1, enabled: true))
        XCTAssertEqual(actions(lifecycle: .flat, cancelEnabled: false), .editCancelLimitOrder(orderIndex: 1, enabled: false))
        XCTAssertEqual(actions(lifecycle: .flat, cancelEnabled: true, isLimitOrderBusy: true), .editCancelLimitOrder(orderIndex: 1, enabled: false))
    }

    func test_actions_restingLimitOrderWithOpenPosition_keepEditCashOut() {
        let position = PerpsPositionSummary(
            positionId: "lighter:1",
            marketId: 1, symbol: "BTC", side: .long, baseSize: 1,
            notionalUsd: 540, marginUsd: 20, equityUsd: 20.5,
            leverage: 27, roiPercent: 2.5, entryPrice: 66541.7,
            liquidationPrice: 64141.75, unrealizedPnlUsd: 0.5,
            realizedPnlUsd: 0, fundingPaidUsd: 0,
            liquidationDistancePercent: -3.02
        )

        XCTAssertEqual(actions(lifecycle: .open(position), cancelEnabled: true), .editCashOut(editEnabled: true, cashOutEnabled: true))
    }

    func test_changeToast_namesTheChangeInsteadOfPlacing() {
        XCTAssertEqual(PerpsAssetPageViewModel.limitOrderChangeToastText(.cancel, isDone: false), TKLocales.Perps.Toast.orderCancelling)
        XCTAssertEqual(PerpsAssetPageViewModel.limitOrderChangeToastText(.cancel, isDone: true), TKLocales.Perps.Toast.orderCancelled)
        XCTAssertEqual(PerpsAssetPageViewModel.limitOrderChangeToastText(.modify, isDone: false), TKLocales.Perps.Toast.orderUpdating)
        XCTAssertEqual(PerpsAssetPageViewModel.limitOrderChangeToastText(.modify, isDone: true), TKLocales.Perps.Toast.orderUpdated)
    }

    private func actions(
        lifecycle: PerpsMarketLifecycle,
        cancelEnabled: Bool,
        isLimitOrderBusy: Bool = false
    ) -> PerpsAssetPageActions {
        PerpsAssetPageViewModel.actions(
            for: lifecycle,
            snapshot: PerpsAssetMarketSnapshot(
                marketId: 1, symbol: "BTC", displayName: "BTC",
                status: "active", maxLeverage: 40, priceDecimals: 2,
                sizeDecimals: 2,
                price: 66141, priceChangePercent: 4.37, priceChangeAmount: 100,
                volume24h: 2_360_000_000, openInterest: 1_700_000_000, fundingRatePercent: nil, about: nil,
                openEnabled: true
            ),
            restingLimitOrder: summary(expiresAtSeconds: 0),
            flags: PerpsTradingFlags(
                openEnabled: true,
                closeEnabled: true,
                cancelEnabled: cancelEnabled,
                addMarginEnabled: true,
                removeMarginEnabled: true,
                autoCloseEnabled: true
            ),
            isAccountActive: true,
            isOpenPositionSubmitting: false,
            isLimitOrderBusy: isLimitOrderBusy
        )
    }

    private func summary(expiresAtSeconds: Int64) -> PerpsLimitOrderSummary {
        PerpsLimitOrderSummary(
            orderIndex: 1,
            clientOrderIndex: 10,
            side: .long,
            limitPrice: 64000,
            remainingBaseAmount: 1,
            expiresAtSeconds: expiresAtSeconds
        )
    }
}
