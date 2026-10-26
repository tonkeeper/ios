import ChainKit
@testable import KeeperCore
import PerpsModels
import TKPerpsAPI
import XCTest

final class PerpsPartialReadsTests: XCTestCase {
    func testAMarginMoveDoesNotHoldBackTheMarketItRunsOn() {
        let pending = makePending(payload: .marginChange(PerpsPendingMarginChange(
            direction: .add,
            allocatedMarginBefore: 100,
            amountUsd: 10
        )))

        XCTAssertFalse(pending.blocksPositionOrders(now: 1000))
    }

    func testAnOpenWithAnOrderOnTheBookHoldsBackItsMarket() {
        let pending = makePending(
            payload: .open(limitPrice: nil),
            orderRefs: [PerpsPendingOrderRef(role: .parent, clientOrderIndex: 7)]
        )

        XCTAssertTrue(pending.blocksPositionOrders(now: 1000))
    }

    func testAnOpenThatNeverPlacedAnOrderStopsHoldingOnceItsTransactionExpires() {
        let pending = makePending(
            payload: .open(limitPrice: nil),
            signedSteps: [makeSignedStep(transactionExpiryUnixMs: 900)]
        )

        XCTAssertTrue(pending.blocksPositionOrders(now: 900))
        XCTAssertFalse(pending.blocksPositionOrders(now: 901))
    }

    func testTheLegsAPositionCarriesBecomeTheRestingOrdersOfItsContext() throws {
        let rules = try makeRules()
        let autoClose = Components.Schemas.PositionAutoClose(
            take_profit: .init(value1: Components.Schemas.PositionAutoCloseLeg(
                order_index: 281_474_976_712_114,
                client_order_index: 1_756_280_400_123,
                trigger_price: "78030.7",
                price: "75765.6",
                order_type: .market,
                valid_to: 1_780_000_000,
                base_size: "0.00812"
            )),
            stop_loss: nil
        )

        let resting = try PerpsPlannerMapping.restingOrders(
            autoClose: autoClose,
            positionSide: .long,
            rules: rules
        )

        let leg = try XCTUnwrap(resting.first)
        XCTAssertEqual(resting.count, 1)
        XCTAssertEqual(leg.orderIndex, 281_474_976_712_114)
        XCTAssertEqual(leg.clientOrderIndex?.int64Value, 1_756_280_400_123)
        XCTAssertEqual(leg.side, PerpsSide.short_)
        XCTAssertEqual(leg.category, PerpsOrderCategory.takeprofit)
        XCTAssertEqual(leg.status, PerpsRestingOrderStatus.open)
        XCTAssertTrue(leg.positionTied)
        XCTAssertEqual(leg.triggerPrice?.int64Value, 780_307)
        XCTAssertEqual(leg.expiryUnixMs?.int64Value, 1_780_000_000_000)
    }

    func testAPositionWithoutLegsLeavesTheContextWithNoRestingOrders() throws {
        let resting = try PerpsPlannerMapping.restingOrders(
            autoClose: nil,
            positionSide: .long,
            rules: makeRules()
        )

        XCTAssertTrue(resting.isEmpty)
    }
}

private extension PerpsPartialReadsTests {
    func makeRules() throws -> PerpsMarketRules {
        try PerpsPlannerMapping.rules(
            market: Components.Schemas.Market(
                market_index: 1,
                symbol: "BTC",
                status: "active",
                price_decimals: 1,
                size_decimals: 5,
                tick_size: "0.1",
                step_size: "0.00001",
                min_size_base: "0.00002",
                max_leverage: 50,
                maker_fee_pct: "0",
                taker_fee_pct: "0.00025",
                initial_margin_fraction: 500,
                maintenance_margin_fraction: 100
            ),
            environment: "mainnet",
            receivedAtUnixMs: 1,
            integrator: .init(
                integrator_account_index: 0,
                integrator_taker_fee: 0,
                integrator_maker_fee: 0,
                max_perps_taker_fee: 0,
                max_perps_maker_fee: 0,
                max_spot_taker_fee: 0,
                max_spot_maker_fee: 0,
                approval_ttl_ms: 0
            )
        )
    }

    func makePending(
        payload: PerpsPendingPayload,
        orderRefs: [PerpsPendingOrderRef]? = nil,
        signedSteps: [PerpsPendingSignedStep]? = nil
    ) -> PerpsPendingTradingAction {
        PerpsPendingTradingAction(
            operationId: "op",
            createdAtMillis: 1,
            walletId: "wallet",
            marketId: 1,
            side: .long,
            payload: payload,
            orderRefs: orderRefs,
            signedSteps: signedSteps
        )
    }

    func makeSignedStep(transactionExpiryUnixMs: Int64) -> PerpsPendingSignedStep {
        PerpsPendingSignedStep(
            stepId: "open",
            attemptId: "attempt",
            nonce: 1,
            transactionExpiryUnixMs: transactionExpiryUnixMs,
            txType: 14,
            txInfo: "payload",
            txHash: "hash",
            state: .unknown
        )
    }
}
