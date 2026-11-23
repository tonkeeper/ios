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

    func testOnlyAnExplicitOpenFlagAllowsAnOpen() {
        XCTAssertFalse(PerpsBackendMapping.openEnabled(nil))
        XCTAssertFalse(PerpsBackendMapping.openEnabled(Components.Schemas.TradingFlags()))
        XCTAssertFalse(
            PerpsBackendMapping.openEnabled(Components.Schemas.TradingFlags(open_enabled: false))
        )
        XCTAssertTrue(PerpsBackendMapping.openEnabled(Components.Schemas.TradingFlags(open_enabled: true)))
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

    func testAWaitingLimitCarriesTheLegsPlacedWithIt() throws {
        let orders = [Self.limitWithStopLoss()]

        let legs = try XCTUnwrap(PerpsBackendMapping.limitOrders(orders).first).autoCloseLegs
        XCTAssertEqual(legs, [PerpsTriggerOrderSummary(
            orderIndex: 13,
            clientOrderIndex: 1003,
            kind: .stopLoss,
            side: .short,
            triggerPrice: 61800,
            baseAmount: 0,
            expiresAtSeconds: 1_795_772_370
        )])
        XCTAssertEqual(
            PerpsBackendMapping.portfolioOrders(orders.map { .init(value1: $0, value2: .init()) }).first?.order.autoCloseLegs,
            legs
        )
    }

    func testALegIsFoundInsideItsLimitByEitherIndexAndTheLimitItselfIsNot() {
        let orders = [Self.limitWithStopLoss()]

        XCTAssertEqual(PerpsBackendMapping.autoCloseLeg(orders, key: 1003)?.orderIndex, 13)
        XCTAssertEqual(PerpsBackendMapping.autoCloseLeg(orders, key: 13)?.clientOrderIndex, 1003)
        XCTAssertNil(PerpsBackendMapping.autoCloseLeg(orders, key: 11))
    }

    static func limitWithStopLoss() -> Components.Schemas.Order {
        Components.Schemas.Order(
            id: "lighter:11",
            order_index: 11,
            client_order_index: 1001,
            market_index: 1,
            symbol: "BTC",
            side: .long,
            _type: .limit,
            category: .open,
            base_size: "0.2",
            price: "67000",
            auto_close: .init(value1: .init(stop_loss: .init(value1: .init(
                order_index: 13,
                client_order_index: 1003,
                trigger_price: "61800",
                price: "58710",
                order_type: .market,
                valid_to: 1_795_772_370
            ))))
        )
    }

    func testALimitWhosePartialFillLeftLessThanTheMarketMinimumIsMarked() {
        let market = Components.Schemas.Market(min_size_base: "0.001", min_size_quote: "10")
        func limit(base: String, filled: String, price: String) -> Components.Schemas.Order {
            Components.Schemas.Order(
                order_index: 11,
                side: .long,
                _type: .limit,
                category: .open,
                base_size: base,
                price: price,
                filled_base: filled
            )
        }

        let atMinimum = PerpsBackendMapping.limitOrders([limit(base: "0.003", filled: "0.002", price: "20000")], market: market)
        let underBase = PerpsBackendMapping.limitOrders([limit(base: "0.003", filled: "0.0025", price: "20000")], market: market)
        let underNotional = PerpsBackendMapping.limitOrders([limit(base: "0.003", filled: "0.002", price: "9000")], market: market)

        XCTAssertEqual(atMinimum.map(\.isBelowMarketMinimum), [false])
        XCTAssertEqual(underBase.map(\.isBelowMarketMinimum), [true])
        XCTAssertEqual(underNotional.map(\.isBelowMarketMinimum), [true])
        XCTAssertEqual(PerpsBackendMapping.limitOrders([limit(base: "0.003", filled: "0.0025", price: "20000")]).map(\.isBelowMarketMinimum), [false])
    }

    func testAReconcileRefusalNamesWhatHappenedToTheOrder() {
        XCTAssertEqual(PerpsBackendMapping.rejectionError(PerpsTkReconcile.orderGone), .orderNotFound)
        XCTAssertEqual(PerpsBackendMapping.rejectionError(PerpsTkReconcile.positionGone), .positionNotFound)
        XCTAssertEqual(PerpsBackendMapping.rejectionError("canceled-too-much-slippage"), .slippageExceeded)
        XCTAssertEqual(PerpsBackendMapping.rejectionError("canceled-post-only"), .serverRejected("canceled-post-only"))
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

        let orders = PerpsBackendMapping.portfolioOrders([btc, reduceOnly, unnamed, takeProfit].map { .init(value1: $0, value2: .init()) })

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

    func testOpenPositionCarriesTheMarkPriceItsRoiWasTakenAt() throws {
        let position = Components.Schemas.OpenPosition(
            market_index: 1,
            side: .long,
            size: "0.008164",
            avg_entry_price: "66541.70",
            mark_price: "66141.25",
            roi_pct: "-16.37"
        )
        XCTAssertEqual(try XCTUnwrap(PerpsBackendMapping.position(position)?.markPrice), 66141.25, accuracy: 1e-9)

        let withoutMarket = Components.Schemas.OpenPosition(market_index: 1, side: .long, size: "0.008164", mark_price: "")
        XCTAssertNil(try XCTUnwrap(PerpsBackendMapping.position(withoutMarket)).markPrice)
    }

    func testTradingFlagsMapEveryCapability() throws {
        let mapped = try XCTUnwrap(PerpsBackendMapping.tradingFlags(Components.Schemas.TradingScreen(
            position: .init(value1: .init(market_index: 1, side: .long, size: "0.002")),
            flags: Components.Schemas.TradingFlags(
                open_enabled: true,
                close_enabled: false,
                cancel_enabled: true,
                add_margin_enabled: false,
                remove_margin_enabled: true,
                auto_close_enabled: false
            )
        )))
        XCTAssertEqual(mapped.openEnabled, true)
        XCTAssertEqual(mapped.closeEnabled, false)
        XCTAssertEqual(mapped.cancelEnabled, true)
        XCTAssertEqual(mapped.addMarginEnabled, false)
        XCTAssertEqual(mapped.removeMarginEnabled, true)
        XCTAssertEqual(mapped.autoCloseEnabled, false)
    }

    func testAScreenWithoutAPositionSaysNothingAboutClosingOrMovingItsMargin() throws {
        let mapped = try XCTUnwrap(PerpsBackendMapping.tradingFlags(Components.Schemas.TradingScreen(
            flags: Components.Schemas.TradingFlags(
                open_enabled: true,
                close_enabled: false,
                cancel_enabled: false,
                add_margin_enabled: false,
                remove_margin_enabled: false,
                auto_close_enabled: false
            )
        )))
        XCTAssertEqual(mapped.openEnabled, true)
        XCTAssertEqual(mapped.cancelEnabled, false)
        XCTAssertEqual(mapped.autoCloseEnabled, false)
        XCTAssertNil(mapped.closeEnabled)
        XCTAssertNil(mapped.addMarginEnabled)
        XCTAssertNil(mapped.removeMarginEnabled)
        XCTAssertTrue(Optional(mapped).canClose)
    }

    func testAnAbsentFlagsBlockIsUnknownRatherThanDenied() {
        XCTAssertNil(PerpsBackendMapping.tradingFlags(Components.Schemas.TradingScreen()))
    }

    func testAPartialFlagsBlockLeavesTheUnsaidCapabilitiesUnknown() throws {
        let mapped = try XCTUnwrap(PerpsBackendMapping.tradingFlags(Components.Schemas.TradingScreen(
            position: .init(value1: .init(market_index: 1, side: .long, size: "0.002")),
            flags: Components.Schemas.TradingFlags(cancel_enabled: true)
        )))
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

    func testALimitPlacementTheServiceHasNotHeardOfStaysPending() {
        XCTAssertEqual(
            PerpsTkReconcile.open(state: positionState(), isLimit: true),
            .pending
        )
    }

    func testALimitTheOpenOrderListHoldsIsPlacedBeforeItsEventArrives() {
        let resting = Components.Schemas.Order(
            order_index: 7,
            client_order_index: 42,
            _type: .limit,
            status: .open,
            category: .open,
            price: "60"
        )
        XCTAssertEqual(
            PerpsTkReconcile.limitOpen(heard: .pending, openOrders: [resting], clientOrderIndex: 42),
            .confirmed
        )
        XCTAssertEqual(
            PerpsTkReconcile.limitOpen(heard: .pending, openOrders: [resting], clientOrderIndex: 43),
            .pending
        )
        XCTAssertEqual(
            PerpsTkReconcile.limitOpen(heard: .pending, openOrders: nil, clientOrderIndex: 42),
            .pending
        )
        XCTAssertEqual(
            PerpsTkReconcile.limitOpen(heard: .failed("canceled"), openOrders: [resting], clientOrderIndex: 42),
            .failed("canceled")
        )
    }

    func testACanceledLimitPlacementFails() {
        XCTAssertEqual(
            PerpsTkReconcile.open(
                state: positionState(orders: [stateOrder(status: "canceled", kind: "limit")]),
                isLimit: true
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
                isLimit: true
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

    func testAnAbsentPositionIsNotOurClose() {
        XCTAssertEqual(
            PerpsTkReconcile.close(state: positionState()),
            .pending
        )
        XCTAssertEqual(
            PerpsTkReconcile.close(state: positionState(), expectedBaseSize: 1),
            .pending
        )
        XCTAssertEqual(
            PerpsTkReconcile.close(
                state: positionState(orders: [stateOrder(status: "filled", reduceOnly: true, filledBase: "1")]),
                expectedBaseSize: 1
            ),
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

    func testCancelDoesNotConfirmWhenOrdersAreUnknown() {
        let change = PerpsPendingLimitOrderChange(orderIndex: 7, kind: .cancel, limitPrice: nil)
        XCTAssertEqual(
            PerpsTkReconcile.limitChange(
                change: change,
                ordersReadable: false,
                matching: nil
            ),
            .pending
        )
    }

    func testACancelStaysPendingWhileTheBookStillHoldsTheOrder() {
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
                )
            ),
            .pending
        )
    }

    func testAnOrderMissingFromTheBookIsNotACancel() {
        let change = PerpsPendingLimitOrderChange(orderIndex: 7, kind: .cancel, limitPrice: nil)
        XCTAssertEqual(
            PerpsTkReconcile.limitChange(
                change: change,
                ordersReadable: true,
                matching: nil
            ),
            .pending
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
        XCTAssertEqual(
            PerpsTkReconcile.limitChange(
                change: change,
                detail: orderDetail(resting: false, status: .filled, price: "100")
            ),
            .failed("order_filled")
        )
    }

    func testAChangeOfAnOrderMissingFromTheScreenGoesByTheOrderItself() throws {
        func refusal(_ detail: Components.Schemas.OrderDetail?, kind: PerpsLimitOrderChangeKind = .cancel) -> PerpsTradingError? {
            do {
                _ = try PerpsBackendMapping.changeTarget(detail, kind: kind)
                return nil
            } catch {
                return error as? PerpsTradingError
            }
        }
        let stillResting = Components.Schemas.OrderDetail(
            order: Components.Schemas.Order(
                id: "lighter:7",
                order_index: 7,
                _type: .limit,
                status: .open,
                category: .open,
                base_size: "1",
                price: "100"
            ),
            resting: true,
            fills: [],
            fills_known: true
        )

        XCTAssertEqual(try PerpsBackendMapping.changeTarget(stillResting, kind: .cancel).orderIndex, 7)
        XCTAssertEqual(refusal(orderDetail(resting: false, status: .filled, price: "100")), .orderFilledBeforeCancel)
        XCTAssertEqual(refusal(orderDetail(resting: false, status: .canceled, price: "100")), .nothingToChange)
        XCTAssertEqual(refusal(nil), .orderNotFound)
        XCTAssertEqual(try PerpsBackendMapping.changeTarget(stillResting, kind: .modify).orderIndex, 7)
        XCTAssertEqual(refusal(orderDetail(resting: false, status: .filled, price: "100"), kind: .modify), .orderNotFound)
        XCTAssertEqual(refusal(orderDetail(resting: false, status: .canceled, price: "100"), kind: .modify), .orderNotFound)
        XCTAssertEqual(PerpsBackendMapping.rejectionError("order_filled"), .orderFilledBeforeCancel)
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
                restingMatchesTarget: true
            ),
            .confirmed
        )
    }

    func testABookThatDoesNotHoldTheChangeKeepsItPending() {
        XCTAssertEqual(
            PerpsTkReconcile.autoCloseChange(
                legs: [.confirmed],
                restingMatchesTarget: false
            ),
            .pending
        )
    }

    func testARefusedLegSettlesTheChangeWhateverTheBookShows() {
        XCTAssertEqual(
            PerpsTkReconcile.autoCloseChange(
                legs: [.confirmed, .failed("rejected")],
                restingMatchesTarget: true
            ),
            .failed("rejected")
        )
    }

    func testLegsThatConfirmThemselvesStandInForABookNobodyCanRead() {
        XCTAssertEqual(
            PerpsTkReconcile.autoCloseChange(
                legs: [.confirmed],
                restingMatchesTarget: nil
            ),
            .confirmed
        )
    }

    func testAnAutoCloseNothingCanBeReadAboutStaysPending() {
        XCTAssertEqual(
            PerpsTkReconcile.autoCloseChange(
                legs: [.pending],
                restingMatchesTarget: nil
            ),
            .pending
        )
        XCTAssertEqual(
            PerpsTkReconcile.autoCloseChange(
                legs: [],
                restingMatchesTarget: nil
            ),
            .pending
        )
    }

    func testASizeChangeFilledWithinWirePrecisionIsConfirmed() {
        XCTAssertEqual(sizeChangeDecision(filledBase: "1", expected: 1), .confirmed)
        XCTAssertEqual(sizeChangeDecision(filledBase: "1.5", expected: 1), .confirmed)
        XCTAssertEqual(sizeChangeDecision(filledBase: "0.9999999995", expected: 1), .confirmed)
        XCTAssertEqual(sizeChangeDecision(filledBase: "0.999999998", expected: 1), .partiallyFilled)
    }

    func testTheFillToleranceGrowsWithALargeSize() {
        XCTAssertEqual(sizeChangeDecision(filledBase: "999999.9995", expected: 1_000_000), .confirmed)
        XCTAssertEqual(sizeChangeDecision(filledBase: "999999.998", expected: 1_000_000), .partiallyFilled)
    }

    func testASmallSizeKeepsTheAbsoluteFillTolerance() {
        XCTAssertEqual(sizeChangeDecision(filledBase: "0.0000099995", expected: 0.00001), .confirmed)
        XCTAssertEqual(sizeChangeDecision(filledBase: "0.000009998", expected: 0.00001), .partiallyFilled)
    }

    func testASizeChangeWithNothingFilledStaysPending() {
        XCTAssertEqual(sizeChangeDecision(filledBase: "0", status: "open", expected: 1), .pending)
        XCTAssertEqual(PerpsTkReconcile.sizeChange(state: positionState(), expectedBaseDelta: 1), .pending)
    }

    func testACanceledSizeChangeIsATradeOnlyIfPartOfItFilled() {
        XCTAssertEqual(sizeChangeDecision(filledBase: "0.4", status: "canceled", expected: 1), .partiallyFilled)
        XCTAssertEqual(sizeChangeDecision(filledBase: "0", status: "canceled", expected: 1), .failed("canceled"))
        XCTAssertEqual(sizeChangeDecision(filledBase: "0.4", status: "canceled", expected: nil), .partiallyFilled)
    }

    func testAFillThatDoesNotSayHowMuchLeavesTheSizeChangeToThePosition() {
        XCTAssertNil(sizeChangeDecision(filledBase: "0.4", expected: nil))
        XCTAssertEqual(sizeChangeDecision(filledBase: "0", status: "open", expected: nil), .pending)

        let change = PerpsPendingSizeChange(direction: .add, baseSizeBefore: 0.008)
        XCTAssertEqual(PerpsTkReconcile.sizeChange(change, currentBaseSize: 0.009), .confirmed)
        XCTAssertEqual(PerpsTkReconcile.sizeChange(change, currentBaseSize: 0.008), .pending)
        XCTAssertEqual(PerpsTkReconcile.sizeChange(change, currentBaseSize: nil), .confirmed)
    }

    func testAMarginMoveTheVenueHasNotMadeFailsOnceItsTransactionCanNoLongerLand() {
        let change = PerpsPendingMarginChange(direction: .add, allocatedMarginBefore: 20, amountUsd: 10)
        XCTAssertEqual(PerpsTkReconcile.marginChange(change, currentMarginUsd: 20, canStillLand: true), .pending)
        XCTAssertEqual(
            PerpsTkReconcile.marginChange(change, currentMarginUsd: 20, canStillLand: false),
            .failed("margin_unchanged")
        )
        XCTAssertEqual(PerpsTkReconcile.marginChange(change, currentMarginUsd: 30, canStillLand: false), .confirmed)
        XCTAssertEqual(
            PerpsTkReconcile.marginChange(change, currentMarginUsd: nil, canStillLand: true),
            .failed("position_gone")
        )
    }

    func testAnOperationWithoutAnOrderKeyWaitsOnlyWhileItsTransactionCanLand() {
        let pending = pendingAction(steps: [signedStep(state: .unknown, expiresAt: 1000)])
        XCTAssertEqual(PerpsTkReconcile.withoutOrderKey(pending, now: 1000), .pending)
        XCTAssertEqual(PerpsTkReconcile.withoutOrderKey(pending, now: 1001), .notSubmitted)
        XCTAssertEqual(PerpsTkReconcile.withoutOrderKey(pendingAction(steps: []), now: 1000), .notSubmitted)
    }

    func testAnOperationWhoseEveryStepWasAcceptedWithoutAnOrderKeyPlacedNoOrder() {
        let pending = pendingAction(steps: [signedStep("leverage", state: .accepted, expiresAt: 1000)])
        XCTAssertEqual(PerpsTkReconcile.withoutOrderKey(pending, now: 1000), .notSubmitted)
    }

    func testAnOrderTheVenueNeverHeardOfIsNotSubmittedOnceItsTransactionExpires() {
        let pending = pendingAction(
            steps: [signedStep(state: .unknown, expiresAt: 1000)],
            refs: [PerpsPendingOrderRef(role: .parent, clientOrderIndex: 7)]
        )
        XCTAssertEqual(PerpsTkReconcile.withOrderKey(.pending, orders: [], pending: pending, now: 1000), .pending)
        XCTAssertEqual(PerpsTkReconcile.withOrderKey(.pending, orders: [], pending: pending, now: 1001), .notSubmitted)
    }

    func testWhatTheVenueSaidOutlivesTheTransaction() {
        let pending = pendingAction(
            steps: [signedStep(state: .unknown, expiresAt: 1000)],
            refs: [PerpsPendingOrderRef(role: .parent, clientOrderIndex: 7)]
        )
        XCTAssertEqual(
            PerpsTkReconcile.withOrderKey(.pending, orders: [stateOrder(status: "open")], pending: pending, now: 1001),
            .pending
        )
        XCTAssertEqual(PerpsTkReconcile.withOrderKey(.confirmed, orders: [], pending: pending, now: 1001), .confirmed)
    }

    func testAStepCaughtMidSendIsOnlyReconciledNeverSentAgain() {
        let pending = pendingAction(steps: [signedStep(state: .sending)])
        XCTAssertEqual(PerpsTkReconcile.interruptedSend(pending), signedStep(state: .unknown))
        XCTAssertNil(PerpsTkReconcile.unsentStep(pending))
    }

    func testAStepSignedButNeverSentIsSent() {
        let pending = pendingAction(steps: [signedStep("leverage", state: .accepted), signedStep(state: .signed)])
        XCTAssertEqual(PerpsTkReconcile.unsentStep(pending), signedStep(state: .signed))
        XCTAssertNil(PerpsTkReconcile.interruptedSend(pending))
    }

    func testAStepWithAKnownOrUnknownOutcomeIsLeftToReconciliation() {
        for state in [PerpsPendingStepState.unknown, .accepted] {
            let pending = pendingAction(steps: [signedStep(state: state)])
            XCTAssertNil(PerpsTkReconcile.interruptedSend(pending))
            XCTAssertNil(PerpsTkReconcile.unsentStep(pending))
        }
    }

    func testARefusedResendDropsTheOperationOnlyWhenNoneOfItCanBeOnTheVenue() {
        let refused = PerpsTradingError.serverRejected("invalid signature")
        XCTAssertTrue(PerpsTkReconcile.refusedSendSettles(refused, pending: pendingAction(steps: [signedStep(state: .signed)])))
        XCTAssertFalse(PerpsTkReconcile.refusedSendSettles(refused, pending: pendingAction(
            steps: [signedStep(state: .signed)],
            refs: [PerpsPendingOrderRef(role: .parent, clientOrderIndex: 7)]
        )))
        XCTAssertFalse(PerpsTkReconcile.refusedSendSettles(refused, pending: pendingAction(
            steps: [signedStep("leverage", state: .accepted), signedStep(state: .signed)]
        )))
    }

    func testAResendWhoseOutcomeIsUnknownIsKept() {
        let pending = pendingAction(steps: [signedStep(state: .signed)])
        let ambiguous: [PerpsTradingError] = [
            .offline, .timeout, .serverUnavailable, .protocolFailure("hash mismatch"), .unknown("reset"),
        ]
        for error in ambiguous {
            XCTAssertFalse(PerpsTkReconcile.refusedSendSettles(error, pending: pending))
        }
    }

    func testAnOpenTakesTheCountedPositionOnlyWhenItIsWhatTheOrderFilled() {
        let filled = [stateOrder(status: "filled", filledBase: "0.0063")]
        XCTAssertEqual(
            PerpsTkReconcile.countedOpen(state: positionState(open: countedEpisode(size: "0.0063"), orders: filled)),
            PerpsCountedPosition(baseSize: 0.0063, entryPrice: 2345.02, leverage: 5, isolatedMarginUsd: 2.953767)
        )
        XCTAssertNil(
            PerpsTkReconcile.countedOpen(state: positionState(open: countedEpisode(size: "0.0031"), orders: filled)),
            "the count lags the fills"
        )
        XCTAssertNil(
            PerpsTkReconcile.countedOpen(state: positionState(open: countedEpisode(size: "0.0126"), orders: filled)),
            "the count holds more than this order"
        )
        XCTAssertNil(PerpsTkReconcile.countedOpen(state: positionState(open: countedEpisode(position: false), orders: filled)))
    }

    func testACrossCountLeavesTheMarginToTheLeverage() {
        let open = countedEpisode(size: "0.0063", marginMode: .cross)
        let counted = PerpsTkReconcile.countedOpen(
            state: positionState(open: open, orders: [stateOrder(status: "filled", filledBase: "0.0063")])
        )
        XCTAssertEqual(counted?.isolatedMarginUsd, nil)

        let opening = PerpsOpeningDescriptor(marketId: 1, symbol: "ETH", side: .short, marginUsd: 3, leverage: 5, isLimit: false)
        var mark = PerpsCountedPosition(baseSize: 2, entryPrice: 100, leverage: nil, isolatedMarginUsd: nil)
        mark.markPrice = 101
        let summary = mark.summary(opening, liquidationPrice: 119)
        XCTAssertEqual(summary.marginUsd, 40, accuracy: 1e-9)
        XCTAssertEqual(summary.unrealizedPnlUsd, -2, accuracy: 1e-9)
        XCTAssertEqual(summary.equityUsd, 38, accuracy: 1e-9)
        XCTAssertEqual(summary.notionalUsd, 202, accuracy: 1e-9)
        XCTAssertEqual(summary.liquidationPrice, 119)
        XCTAssertEqual(summary.positionId, "lighter:1")
    }
}

private func sizeChangeDecision(
    filledBase: String,
    status: String = "filled",
    expected: Double?
) -> PerpsTkReconcile.Decision? {
    PerpsTkReconcile.sizeChange(
        state: positionState(orders: [stateOrder(status: status, filledBase: filledBase)]),
        expectedBaseDelta: expected
    )
}

private func pendingAction(
    steps: [PerpsPendingSignedStep],
    refs: [PerpsPendingOrderRef]? = nil
) -> PerpsPendingTradingAction {
    PerpsPendingTradingAction(
        operationId: "op",
        createdAtMillis: 1,
        walletId: "wallet",
        marketId: 1,
        side: .long,
        payload: .open(limitPrice: nil),
        orderRefs: refs,
        signedSteps: steps
    )
}

private func signedStep(
    _ stepId: String = "open",
    state: PerpsPendingStepState,
    expiresAt: Int64 = 1000
) -> PerpsPendingSignedStep {
    PerpsPendingSignedStep(
        stepId: stepId,
        attemptId: "attempt",
        nonce: 1,
        transactionExpiryUnixMs: expiresAt,
        txType: 14,
        txInfo: "payload",
        txHash: "hash",
        state: state
    )
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

private func countedEpisode(
    size: String = "0.0063",
    marginMode: Components.Schemas.MarginMode = .isolated,
    position: Bool = true
) -> Components.Schemas.PositionEpisode {
    .init(
        episode_id: "29800309063",
        side: .long,
        opened_at: Date(),
        open_seen: true,
        position: position ? .init(value1: .init(
            size: size,
            avg_entry_price: "2345.02",
            leverage: 5,
            margin_mode: .init(value1: marginMode),
            allocated_margin: "2.953767",
            last_trade_id: "29800309071"
        )) : nil
    )
}
