import Foundation
@testable import KeeperCore
import PerpsModels
import TKPerpsAPI
import XCTest

final class PerpsBackendMappingTests: XCTestCase {
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

    func testOrdersAreReadableWhenTheScreenCarriesTheList() {
        XCTAssertFalse(PerpsBackendMapping.ordersReadable(Components.Schemas.TradingScreen()))
        XCTAssertTrue(
            PerpsBackendMapping.ordersReadable(Components.Schemas.TradingScreen(open_orders: []))
        )
    }

    func testAMissingOpenFlagDoesNotReadAsARefusal() {
        XCTAssertTrue(PerpsBackendMapping.openEnabled(nil))
        XCTAssertTrue(PerpsBackendMapping.openEnabled(Components.Schemas.TradingFlags()))
        XCTAssertFalse(
            PerpsBackendMapping.openEnabled(Components.Schemas.TradingFlags(open_enabled: false))
        )
    }

    func testAMarketWithNothingToCancelStillReadsItsOrders() {
        let screen = Components.Schemas.TradingScreen(
            open_orders: [],
            flags: Components.Schemas.TradingFlags(cancel_enabled: false)
        )

        XCTAssertTrue(PerpsBackendMapping.ordersReadable(screen))
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

    func testPortfolioOrdersKeepEveryRestingOrderTheHomeCanName() {
        let btc = Components.Schemas.Order(
            order_index: 21,
            market_index: 1,
            symbol: "BTC",
            side: .short,
            _type: .limit,
            category: .open,
            base_size: "0.0003",
            price: "90000"
        )
        let reduceOnly = Components.Schemas.Order(
            order_index: 24,
            market_index: 2,
            symbol: "ETH",
            side: .short,
            _type: .limit,
            category: .open,
            base_size: "0.5",
            price: "3200",
            reduce_only: true
        )
        let unnamed = Components.Schemas.Order(
            order_index: 22,
            market_index: 2,
            side: .long,
            _type: .limit,
            category: .open,
            base_size: "1",
            price: "3000"
        )
        let takeProfit = Components.Schemas.Order(
            order_index: 23,
            market_index: 1,
            symbol: "BTC",
            side: .short,
            _type: .limit,
            category: .take_profit,
            trigger_price: "95000"
        )

        let orders = PerpsBackendMapping.portfolioOrders([btc, reduceOnly, unnamed, takeProfit])

        XCTAssertEqual(orders.map(\.order.orderIndex), [21, 24])
        XCTAssertEqual(orders.first?.symbol, "BTC")
        XCTAssertEqual(orders.first?.order.orderIndex, 21)
        XCTAssertEqual(orders.first?.order.side, .short)
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
            equity: "402.5",
            positions: [position]
        )
        XCTAssertEqual(snapshot.availableBalance, "12.5")
        XCTAssertEqual(snapshot.equity, "402.5")
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

    func testSnapshotWithoutEquityFallsBackToTheFreeBalance() {
        let snapshot = PerpsBackendMapping.snapshot(
            availableBalance: "12.5",
            equity: nil,
            positions: nil
        )
        XCTAssertEqual(snapshot.equity, "12.5")
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

    func testAnAcceptedLimitPlacementIsConfirmedBeforeTheVenueSpeaks() {
        XCTAssertEqual(
            PerpsTkReconcile.open(
                state: positionState(),
                isLimit: true,
                placementAccepted: true
            ),
            .confirmed
        )
    }

    func testALimitPlacementNobodyAcceptedStaysPending() {
        XCTAssertEqual(
            PerpsTkReconcile.open(
                state: positionState(),
                isLimit: true,
                placementAccepted: false
            ),
            .pending
        )
    }

    func testWhatTheVenueSaysOutranksTheAcceptedPlacement() {
        XCTAssertEqual(
            PerpsTkReconcile.open(
                state: positionState(orders: [stateOrder(status: "canceled", kind: "limit")]),
                isLimit: true,
                placementAccepted: true
            ),
            .failed("canceled")
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

    func testAMarketOpenThatFilledShortIsATradeNotARefusal() {
        XCTAssertEqual(
            PerpsTkReconcile.open(
                state: positionState(orders: [stateOrder(status: "canceled", filledBase: "0.4")]),
                isLimit: false,
                expectedBaseSize: 1
            ),
            .partiallyFilled
        )
        XCTAssertEqual(
            PerpsTkReconcile.open(
                state: positionState(orders: [stateOrder(status: "filled", filledBase: "0.4")]),
                isLimit: false,
                expectedBaseSize: 1
            ),
            .partiallyFilled
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

    func testTheVenuesCancelSubStatusesAreCancelsToo() {
        XCTAssertEqual(
            PerpsTkReconcile.open(
                state: positionState(orders: [stateOrder(status: "canceled-too-much-slippage")]),
                isLimit: false,
                expectedBaseSize: 1
            ),
            .failed("canceled-too-much-slippage")
        )
        XCTAssertEqual(
            PerpsTkReconcile.open(
                state: positionState(orders: [stateOrder(status: "canceled-post-only", kind: "limit")]),
                isLimit: true,
                placementAccepted: true
            ),
            .failed("canceled-post-only")
        )
        XCTAssertTrue(PerpsBackendMapping.isSlippageCancel("canceled-too-much-slippage"))
        XCTAssertFalse(PerpsBackendMapping.isSlippageCancel("canceled-post-only"))
        XCTAssertFalse(PerpsBackendMapping.isSlippageCancel("canceled"))
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

    func testACloseThatFilledShortIsNotARefusalEither() {
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
            .partiallyFilled
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

    func testCancelDoesNotConfirmWhenOrdersAreUnknownAndNothingWasAccepted() {
        let change = PerpsPendingLimitOrderChange(orderIndex: 7, kind: .cancel, limitPrice: nil)
        XCTAssertEqual(
            PerpsTkReconcile.limitChange(
                change: change,
                ordersReadable: false,
                matching: nil,
                placementAccepted: false
            ),
            .pending
        )
    }

    func testAnAcceptedCancelSettlesWhenTheBookCannotBeRead() {
        let change = PerpsPendingLimitOrderChange(orderIndex: 7, kind: .cancel, limitPrice: nil)
        XCTAssertEqual(
            PerpsTkReconcile.limitChange(
                change: change,
                ordersReadable: false,
                matching: nil,
                placementAccepted: true
            ),
            .confirmed
        )
    }

    func testAReadableBookOutranksTheAcceptedCancel() {
        let change = PerpsPendingLimitOrderChange(orderIndex: 7, kind: .cancel, limitPrice: nil)
        XCTAssertEqual(
            PerpsTkReconcile.limitChange(
                change: change,
                ordersReadable: true,
                matching: Components.Schemas.Order(
                    order_index: 7,
                    _type: .limit,
                    status: .open,
                    category: .open,
                    price: "100"
                ),
                placementAccepted: true
            ),
            .pending
        )
    }

    func testCancelConfirmsWhenVisibleBookNoLongerHasTheOrder() {
        let change = PerpsPendingLimitOrderChange(orderIndex: 7, kind: .cancel, limitPrice: nil)
        XCTAssertEqual(
            PerpsTkReconcile.limitChange(
                change: change,
                ordersReadable: true,
                matching: nil,
                placementAccepted: false
            ),
            .confirmed
        )
    }

    func testTheOrderItselfAnswersACancelWhereverItIsNow() {
        let change = PerpsPendingLimitOrderChange(
            orderIndex: 7,
            kind: .cancel,
            limitPrice: nil,
            orderId: "lighter:7"
        )

        XCTAssertEqual(
            PerpsTkReconcile.limitChange(
                change: change,
                detail: orderDetail(resting: true, status: .open, price: "100")
            ),
            .pending
        )
        XCTAssertEqual(
            PerpsTkReconcile.limitChange(
                change: change,
                detail: orderDetail(resting: false, status: .canceled, price: "100")
            ),
            .confirmed
        )
    }

    func testTheOrderItselfAnswersAModifyByItsNewPrice() {
        let change = PerpsPendingLimitOrderChange(
            orderIndex: 7,
            kind: .modify,
            limitPrice: 105,
            orderId: "lighter:7"
        )

        XCTAssertEqual(
            PerpsTkReconcile.limitChange(
                change: change,
                detail: orderDetail(resting: true, status: .open, price: "105")
            ),
            .confirmed
        )
        XCTAssertEqual(
            PerpsTkReconcile.limitChange(
                change: change,
                detail: orderDetail(resting: true, status: .open, price: "100")
            ),
            .pending
        )
        XCTAssertEqual(
            PerpsTkReconcile.limitChange(
                change: change,
                detail: orderDetail(resting: false, status: .canceled, price: "100")
            ),
            .failed("order_gone")
        )
    }

    private func orderDetail(
        resting: Bool,
        status: Components.Schemas.OrderStatus,
        price: String
    ) -> Components.Schemas.OrderDetail {
        Components.Schemas.OrderDetail(
            order: Components.Schemas.Order(
                id: "lighter:7",
                order_index: 7,
                _type: .limit,
                status: status,
                category: .open,
                price: price
            ),
            resting: resting,
            fills: [],
            fills_known: true
        )
    }

    func testATriggerOrderTheVenueHasNotHeardOfStillConfirmsFromTheBook() {
        XCTAssertEqual(
            PerpsTkReconcile.autoCloseChange(
                legs: [.pending],
                restingMatchesTarget: true,
                placementAccepted: false
            ),
            .confirmed
        )
    }

    func testABookThatDoesNotHoldTheChangeKeepsItPending() {
        XCTAssertEqual(
            PerpsTkReconcile.autoCloseChange(
                legs: [.confirmed],
                restingMatchesTarget: false,
                placementAccepted: true
            ),
            .pending
        )
    }

    func testARefusedLegSettlesTheChangeWhateverTheBookShows() {
        XCTAssertEqual(
            PerpsTkReconcile.autoCloseChange(
                legs: [.confirmed, .failed("rejected")],
                restingMatchesTarget: true,
                placementAccepted: true
            ),
            .failed("rejected")
        )
    }

    func testLegsThatConfirmThemselvesStandInForABookNobodyCanRead() {
        XCTAssertEqual(
            PerpsTkReconcile.autoCloseChange(
                legs: [.confirmed],
                restingMatchesTarget: nil,
                placementAccepted: false
            ),
            .confirmed
        )
    }

    func testAnAcceptedAutoCloseSettlesWhenNothingCanBeRead() {
        XCTAssertEqual(
            PerpsTkReconcile.autoCloseChange(
                legs: [.pending],
                restingMatchesTarget: nil,
                placementAccepted: true
            ),
            .confirmed
        )
        XCTAssertEqual(
            PerpsTkReconcile.autoCloseChange(
                legs: [],
                restingMatchesTarget: nil,
                placementAccepted: false
            ),
            .pending
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
