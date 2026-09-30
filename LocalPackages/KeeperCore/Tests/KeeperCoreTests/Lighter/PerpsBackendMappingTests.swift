import Foundation
@testable import KeeperCore
import TKPerpsAPI
import XCTest

final class PerpsBackendMappingTests: XCTestCase {
    func testAClosingFillBelongsToThePositionOppositeItsOrderSide() {
        let closedShort = makeActivityItem(side: .long, realizedPnl: "12.5")
        XCTAssertEqual(closedShort.outcome, .closed)
        XCTAssertEqual(closedShort.side, .long)
        XCTAssertEqual(closedShort.positionSide, .short)

        let closedLong = makeActivityItem(side: .short, realizedPnl: "-3")
        XCTAssertEqual(closedLong.positionSide, .long)
    }

    func testAnOpeningFillKeepsItsOrderSide() {
        let openedShort = makeActivityItem(side: .short, realizedPnl: nil)
        XCTAssertEqual(openedShort.outcome, .opened)
        XCTAssertEqual(openedShort.positionSide, .short)

        let openedLong = makeActivityItem(side: .long, realizedPnl: nil)
        XCTAssertEqual(openedLong.positionSide, .long)
    }

    func testALiquidationBelongsToThePositionItClosed() {
        let liquidatedLong = makeActivityItem(side: .short, realizedPnl: "-40", type: .liquidation)
        XCTAssertEqual(liquidatedLong.outcome, .liquidated)
        XCTAssertEqual(liquidatedLong.positionSide, .long)
    }

    func testAnItemWithoutASideHasNoPositionSide() {
        XCTAssertNil(makeActivityItem(side: nil, realizedPnl: "1").positionSide)
    }

    func testPositionIgnoresZeroSize() {
        let position = Components.Schemas.OpenPosition(
            market_index: 1,
            symbol: "BTC",
            side: .long,
            size: "0",
            margin: "10"
        )
        XCTAssertNil(PerpsBackendMapping.position(position))
    }

    func testPositionMapsQuoteAndSide() throws {
        let position = Components.Schemas.OpenPosition(
            market_index: 7,
            symbol: "ETH",
            side: .short,
            size: "1.5",
            position_value: "3000",
            avg_entry_price: "2000",
            liquidation_price: "2500",
            margin: "400",
            unrealized_pnl: "-10",
            realized_pnl: "2",
            funding_paid: "-1.2"
        )
        let mapped = try XCTUnwrap(PerpsBackendMapping.position(position))
        XCTAssertEqual(mapped.marketId, 7)
        XCTAssertEqual(mapped.symbol, "ETH")
        XCTAssertEqual(mapped.side, .short)
        XCTAssertEqual(mapped.baseSize, 1.5)
        XCTAssertEqual(mapped.notionalUsd, 3000)
        XCTAssertEqual(mapped.marginUsd, 400)
        XCTAssertEqual(mapped.entryPrice, 2000)
        XCTAssertEqual(mapped.liquidationPrice, 2500)
        XCTAssertEqual(mapped.unrealizedPnlUsd, -10)
        XCTAssertEqual(mapped.realizedPnlUsd, 2)
        XCTAssertEqual(mapped.fundingPaidUsd, Optional(-1.2))
    }

    func testPositionKeepsTheIdTheListGaveItRatherThanARecomposedOne() throws {
        let renamed = Components.Schemas.OpenPosition(
            id: "lighter:mainnet:1",
            market_index: 1,
            symbol: "BTC",
            side: .long,
            size: "0.009",
            margin: "20"
        )
        XCTAssertEqual(try XCTUnwrap(PerpsBackendMapping.position(renamed)).positionId, "lighter:mainnet:1")

        let idless = Components.Schemas.OpenPosition(
            market_index: 1,
            symbol: "BTC",
            side: .long,
            size: "0.009",
            margin: "20"
        )
        XCTAssertEqual(
            try XCTUnwrap(PerpsBackendMapping.position(idless)).positionId,
            PerpsPlannerMapping.tkPositionId(marketId: 1)
        )
    }

    func testLeverageComesFromTheVenueNotFromNotionalOverMargin() throws {
        let drifted = Components.Schemas.OpenPosition(
            market_index: 1,
            symbol: "BTC",
            side: .long,
            size: "0.009",
            position_value: "594",
            margin: "20",
            leverage: 27
        )
        XCTAssertEqual(try XCTUnwrap(PerpsBackendMapping.position(drifted)).leverage, 27)

        let underivable = Components.Schemas.OpenPosition(
            market_index: 1,
            symbol: "BTC",
            side: .long,
            size: "0.009",
            position_value: "594",
            margin: "20",
            leverage: 0
        )
        XCTAssertNil(try XCTUnwrap(PerpsBackendMapping.position(underivable)).leverage)

        let absent = Components.Schemas.OpenPosition(
            market_index: 1,
            symbol: "BTC",
            side: .long,
            size: "0.009",
            position_value: "594",
            margin: "20"
        )
        XCTAssertNil(try XCTUnwrap(PerpsBackendMapping.position(absent)).leverage)
    }

    func testEffectiveLeverageFallsBackToTheRatioOnlyWhenTheVenueCannotDerive() throws {
        let derived = Components.Schemas.OpenPosition(
            market_index: 1, symbol: "BTC", side: .long, size: "0.009",
            position_value: "594", margin: "20", leverage: 27
        )
        XCTAssertEqual(try XCTUnwrap(PerpsBackendMapping.position(derived)).effectiveLeverage ?? .nan, 27, accuracy: 1e-9)

        let underivable = Components.Schemas.OpenPosition(
            market_index: 1, symbol: "BTC", side: .long, size: "0.009",
            position_value: "594", margin: "20", leverage: 0
        )
        let mapped = try XCTUnwrap(PerpsBackendMapping.position(underivable))
        XCTAssertNil(mapped.leverage)
        XCTAssertEqual(mapped.effectiveLeverage ?? .nan, 29.7, accuracy: 1e-9)

        let marginless = Components.Schemas.OpenPosition(
            market_index: 1, symbol: "BTC", side: .long, size: "0.009",
            position_value: "594", margin: "0", leverage: 0
        )
        XCTAssertNil(try XCTUnwrap(PerpsBackendMapping.position(marginless)).effectiveLeverage)
    }

    func testOpenOrdersAreHiddenUnlessCancelEnabled() {
        XCTAssertFalse(PerpsBackendMapping.ordersVisible(nil))
        XCTAssertFalse(PerpsBackendMapping.ordersVisible(.init(cancel_enabled: false)))
        XCTAssertTrue(PerpsBackendMapping.ordersVisible(.init(cancel_enabled: true)))
    }

    func testLimitAndTriggerOrdersSplitByCategory() {
        let limit = Components.Schemas.Order(
            order_index: 11,
            client_order_index: 1001,
            side: .long,
            _type: .limit,
            category: .open,
            base_size: "0.2",
            price: "67000",
            filled_base: "0.05"
        )
        let takeProfit = Components.Schemas.Order(
            order_index: 12,
            client_order_index: 1002,
            side: .short,
            _type: .limit,
            status: .open,
            category: .take_profit,
            trigger_price: "72000"
        )
        let orders = [limit, takeProfit]
        XCTAssertEqual(PerpsBackendMapping.limitOrders(orders).map(\.orderIndex), [11])
        XCTAssertEqual(PerpsBackendMapping.triggerOrders(orders).map(\.kind), [.takeProfit])
    }

    func testPendingWithoutOrderRefsSurvivesTheJournalRoundTrip() throws {
        let pending = PerpsPendingTradingAction(
            operationId: "op",
            createdAtMillis: 1,
            walletId: "wallet",
            marketId: 1,
            side: .long,
            payload: .open(limitPrice: nil)
        )

        let restored = try JSONDecoder().decode(
            PerpsPendingTradingAction.self,
            from: JSONEncoder().encode(pending)
        )

        XCTAssertEqual(restored, pending)
        XCTAssertNil(restored.orderRefs)
        XCTAssertNil(restored.positionOrderRef)
    }

    func testSnapshotUsesOpenPositionsList() throws {
        let position = Components.Schemas.OpenPosition(
            id: "lighter:7",
            market_index: 7,
            symbol: "ETH",
            side: .short,
            size: "1.5",
            position_value: "3000",
            avg_entry_price: "2000",
            liquidation_price: "2500",
            margin: "400",
            unrealized_pnl: "-10",
            realized_pnl: "2",
            funding_paid: "-1.2"
        )
        let snapshot = PerpsBackendMapping.snapshot(
            availableBalance: "12.5",
            positions: [position]
        )
        XCTAssertEqual(snapshot.availableBalance, "12.5")
        let mapped = try XCTUnwrap(snapshot.positions.first)
        XCTAssertEqual(mapped.marketId, 7)
        XCTAssertEqual(mapped.baseSize, 1.5)
        XCTAssertEqual(mapped.marginUsd, 400)
    }

    func testOpenPositionCarriesTheVenueLiquidationDistance() throws {
        let position = Components.Schemas.OpenPosition(
            market_index: 1,
            symbol: "BTC",
            side: .long,
            size: "0.008164",
            position_value: "540",
            avg_entry_price: "66541.70",
            liquidation_price: "64141.75",
            liquidation_distance_pct: "-3.02",
            margin: "19.98",
            unrealized_pnl: "-3.27",
            realized_pnl: "0",
            roi_pct: "-16.37",
            leverage: 27
        )
        let mapped = try XCTUnwrap(PerpsBackendMapping.position(position))
        XCTAssertEqual(try XCTUnwrap(mapped.liquidationDistancePercent), -3.02, accuracy: 1e-9)
    }

    func testTradingFlagsMapEveryCapability() throws {
        let mapped = try XCTUnwrap(PerpsBackendMapping.tradingFlags(Components.Schemas.TradingFlags(
            open_enabled: true,
            close_enabled: false,
            cancel_enabled: true,
            add_margin_enabled: false,
            remove_margin_enabled: true,
            auto_close_enabled: false
        )))
        XCTAssertEqual(mapped.openEnabled, true)
        XCTAssertEqual(mapped.closeEnabled, false)
        XCTAssertEqual(mapped.cancelEnabled, true)
        XCTAssertEqual(mapped.addMarginEnabled, false)
        XCTAssertEqual(mapped.removeMarginEnabled, true)
        XCTAssertEqual(mapped.autoCloseEnabled, false)
    }

    func testAnAbsentFlagsBlockIsUnknownRatherThanDenied() {
        XCTAssertNil(PerpsBackendMapping.tradingFlags(nil))
    }

    func testAPartialFlagsBlockLeavesTheUnsaidCapabilitiesUnknown() throws {
        let mapped = try XCTUnwrap(
            PerpsBackendMapping.tradingFlags(Components.Schemas.TradingFlags(cancel_enabled: true))
        )
        XCTAssertEqual(mapped.cancelEnabled, true)
        XCTAssertNil(mapped.closeEnabled)
        XCTAssertNil(mapped.openEnabled)
        XCTAssertNil(mapped.addMarginEnabled)
        XCTAssertNil(mapped.removeMarginEnabled)
        XCTAssertNil(mapped.autoCloseEnabled)
    }

    func testTkPositionIdMatchesListIdShape() {
        XCTAssertEqual(PerpsPlannerMapping.tkPositionId(marketId: 1), "lighter:1")
    }
}

final class PerpsTkReconcileTests: XCTestCase {
    func testMarketOpenStaysPendingUntilTheOrderIsHeard() {
        let open = Components.Schemas.PositionEpisode(
            episode_id: "1",
            side: .long,
            opened_at: Date(),
            open_seen: true
        )
        XCTAssertEqual(
            PerpsTkReconcile.open(state: positionState(open: open), isLimit: false),
            .pending
        )
        XCTAssertEqual(
            PerpsTkReconcile.open(
                state: positionState(orders: [stateOrder(status: "filled")]),
                isLimit: false
            ),
            .confirmed
        )
    }

    func testAPartiallyFilledOrderCountsAsATradeWhateverItsStatusSays() {
        XCTAssertEqual(
            PerpsTkReconcile.open(
                state: positionState(orders: [stateOrder(status: "canceled", filledBase: "0.00014")]),
                isLimit: false
            ),
            .confirmed
        )
    }

    func testMarketOpenPartialFillDoesNotConfirmWhenExpectedSizeIsKnown() {
        XCTAssertEqual(
            PerpsTkReconcile.open(
                state: positionState(orders: [stateOrder(status: "canceled", filledBase: "0.4")]),
                isLimit: false,
                expectedBaseSize: 1
            ),
            .failed("partial_fill")
        )
        XCTAssertEqual(
            PerpsTkReconcile.open(
                state: positionState(orders: [stateOrder(status: "filled", filledBase: "1")]),
                isLimit: false,
                expectedBaseSize: 1
            ),
            .confirmed
        )
    }

    func testCanceledOpenFailsEvenWhenThereIsNoPosition() {
        XCTAssertEqual(
            PerpsTkReconcile.open(
                state: positionState(orders: [stateOrder(status: "canceled")]),
                isLimit: false
            ),
            .failed("canceled")
        )
    }

    func testLimitOpenConfirmsOnWorkingOrder() {
        XCTAssertEqual(
            PerpsTkReconcile.open(
                state: positionState(orders: [stateOrder(status: "open", kind: "limit")]),
                isLimit: true
            ),
            .confirmed
        )
        XCTAssertEqual(
            PerpsTkReconcile.open(
                state: positionState(orders: [stateOrder(status: "open", kind: "limit")]),
                isLimit: false
            ),
            .pending
        )
    }

    func testCloseWithoutBaselineDoesNotTreatAnAbsentPositionAsOurFill() {
        XCTAssertEqual(
            PerpsTkReconcile.close(state: positionState()),
            .pending
        )
        XCTAssertEqual(
            PerpsTkReconcile.close(state: positionState(), expectedBaseSize: 1),
            .confirmed
        )
        XCTAssertEqual(
            PerpsTkReconcile.close(
                state: positionState(orders: [stateOrder(status: "filled", reduceOnly: true)])
            ),
            .confirmed
        )
    }

    func testCloseKeepsPollingWhileThePositionIsStillThere() {
        let open = Components.Schemas.PositionEpisode(
            episode_id: "1",
            side: .long,
            opened_at: Date(),
            open_seen: true
        )
        XCTAssertEqual(
            PerpsTkReconcile.close(state: positionState(open: open)),
            .pending
        )
        XCTAssertEqual(
            PerpsTkReconcile.close(
                state: positionState(open: open, orders: [stateOrder(status: "canceled", reduceOnly: true)])
            ),
            .failed("canceled")
        )
    }

    func testFullClosePartialFillDoesNotConfirm() {
        let open = Components.Schemas.PositionEpisode(
            episode_id: "1",
            side: .long,
            opened_at: Date(),
            open_seen: true
        )
        XCTAssertEqual(
            PerpsTkReconcile.close(
                state: positionState(
                    open: open,
                    orders: [stateOrder(status: "canceled", filledBase: "0.4")]
                ),
                expectedBaseSize: 1
            ),
            .failed("partial_fill")
        )
    }

    func testAutoCloseLegConfirmsWhileItRestsAndFailsWhenRefused() {
        XCTAssertEqual(
            PerpsTkReconcile.autoCloseLeg(state: positionState()),
            .pending
        )
        XCTAssertEqual(
            PerpsTkReconcile.autoCloseLeg(
                state: positionState(orders: [stateOrder(status: "open", kind: "take-profit", reduceOnly: true)])
            ),
            .confirmed
        )
        XCTAssertEqual(
            PerpsTkReconcile.autoCloseLeg(
                state: positionState(orders: [stateOrder(status: "rejected", kind: "stop-loss", reduceOnly: true)])
            ),
            .failed("rejected")
        )
    }

    func testCancelDoesNotConfirmWhenOrdersAreUnknown() {
        let change = PerpsPendingLimitOrderChange(orderIndex: 7, kind: .cancel, limitPrice: nil)
        XCTAssertEqual(
            PerpsTkReconcile.limitChange(change: change, ordersVisible: false, matching: nil),
            .pending
        )
    }

    func testCancelConfirmsWhenVisibleBookNoLongerHasTheOrder() {
        let change = PerpsPendingLimitOrderChange(orderIndex: 7, kind: .cancel, limitPrice: nil)
        XCTAssertEqual(
            PerpsTkReconcile.limitChange(change: change, ordersVisible: true, matching: nil),
            .confirmed
        )
    }
}

private func positionState(
    open: Components.Schemas.PositionEpisode? = nil,
    lastClosed: Components.Schemas.PositionEpisode? = nil,
    orders: [Components.Schemas.PositionStateOrder] = []
) -> Components.Schemas.PositionState {
    .init(
        market_index: 1,
        open: open.map { .init(value1: $0) },
        last_closed: lastClosed.map { .init(value1: $0) },
        orders: orders
    )
}

private func stateOrder(
    status: String,
    kind: String = "market",
    reduceOnly: Bool = false,
    filledBase: String = "0"
) -> Components.Schemas.PositionStateOrder {
    .init(
        order_index: 1,
        kind: kind,
        status: status,
        filled_base: filledBase,
        reduce_only: reduceOnly
    )
}

private func makeActivityItem(
    side: Components.Schemas.OrderSide?,
    realizedPnl: String?,
    type: Components.Schemas.ActivityType = .fill
) -> PerpsActivityItem {
    let item = Components.Schemas.ActivityItem(
        id: "act_1",
        _type: type,
        timestamp: Date(timeIntervalSince1970: 0),
        market_index: 1,
        side: side.map { .init(value1: $0) },
        size: "1",
        price: "100",
        realized_pnl: realizedPnl
    )
    return PerpsBackendMapping.activity(item)!
}
