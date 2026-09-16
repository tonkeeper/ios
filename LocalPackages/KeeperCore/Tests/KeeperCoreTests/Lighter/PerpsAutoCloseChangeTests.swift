import ChainKit
@testable import KeeperCore
import XCTest

/// Auto-close replacement sets new protection before canceling stale legs and
/// confirms by the trigger-order delta.
final class PerpsAutoCloseChangeTests: XCTestCase {
    // MARK: - Tx plan

    func testNonEmptyTargetReplacesAllDistinctRestingOrders() {
        let target = Self.autoClose(tp: 68141.70, sl: 64720.16)
        let plan = PerpsAutoCloseChangePlanner.plan(target: target, resting: [
            Self.leg(orderIndex: 101, clientOrderIndex: 1, kind: .takeProfit, price: 70000),
            Self.leg(orderIndex: 102, clientOrderIndex: 2, kind: .stopLoss, price: 60000),
        ])
        XCTAssertEqual(plan, .replace(target: target, staleOrderIndexes: [1, 2]))
    }

    func testNilClientIndexFallsBackToVenueOrderIndex() {
        let plan = PerpsAutoCloseChangePlanner.plan(
            target: PerpsAutoClose(takeProfit: nil, stopLoss: nil),
            resting: [Self.leg(orderIndex: 101, clientOrderIndex: 0, kind: .takeProfit, price: 70000)]
        )

        XCTAssertEqual(plan, .clear(orderIndexes: [101]))
    }

    func testClearingSharedIndexPairDeduplicatesTheCancel() {
        let plan = PerpsAutoCloseChangePlanner.plan(
            target: PerpsAutoClose(takeProfit: nil, stopLoss: nil),
            resting: [
                Self.leg(orderIndex: 7, kind: .takeProfit, price: 70000),
                Self.leg(orderIndex: 7, kind: .stopLoss, price: 60000),
            ]
        )
        XCTAssertEqual(plan, .clear(orderIndexes: [7]))
    }

    func testClearingLegsOnDistinctIndexesCancelsBothInStableOrder() {
        let plan = PerpsAutoCloseChangePlanner.plan(
            target: PerpsAutoClose(takeProfit: nil, stopLoss: nil),
            resting: [
                Self.leg(orderIndex: 1, kind: .takeProfit, price: 70000),
                Self.leg(orderIndex: 2, kind: .stopLoss, price: 60000),
            ]
        )
        XCTAssertEqual(plan, .clear(orderIndexes: [1, 2]))
    }

    func testClearingNothingIsNoChange() {
        let plan = PerpsAutoCloseChangePlanner.plan(target: PerpsAutoClose(takeProfit: nil, stopLoss: nil), resting: [])
        XCTAssertEqual(plan, .noChange)
    }

    // MARK: - Confirmation predicate

    func testSetConfirmsOnlyWhenLiveLegsMatchTargetExactly() {
        let pending = PerpsPendingAutoCloseChange(
            target: Self.autoClose(tp: 68141.70, sl: 64720.16),
            restingOrderIndexes: [1, 2]
        )
        XCTAssertFalse(PerpsAutoCloseChangePlanner.isConfirmed(pending: pending, orders: []))
        XCTAssertFalse(
            PerpsAutoCloseChangePlanner.isConfirmed(pending: pending, orders: [
                Self.leg(orderIndex: 3, kind: .takeProfit, price: 68141.70),
            ]),
            "a missing SL leg must not confirm"
        )
        XCTAssertTrue(PerpsAutoCloseChangePlanner.isConfirmed(pending: pending, orders: [
            Self.leg(orderIndex: 3, kind: .takeProfit, price: 68141.70),
            Self.leg(orderIndex: 3, kind: .stopLoss, price: 64720.16),
        ]))
    }

    func testSetNeverConfirmsWhenVenueStacksInsteadOfReplacing() {
        let pending = PerpsPendingAutoCloseChange(
            target: Self.autoClose(tp: 68141.70, sl: nil),
            restingOrderIndexes: [1]
        )
        XCTAssertFalse(
            PerpsAutoCloseChangePlanner.isConfirmed(pending: pending, orders: [
                Self.leg(orderIndex: 1, kind: .takeProfit, price: 70000),
                Self.leg(orderIndex: 3, kind: .takeProfit, price: 68141.70),
            ]),
            "two TP legs mean the venue stacked — the change must stay unconfirmed"
        )
    }

    func testCancelConfirmsWhenRestingIndexesAreGoneWhateverTheReason() {
        let pending = PerpsPendingAutoCloseChange(target: nil, restingOrderIndexes: [7])
        XCTAssertFalse(PerpsAutoCloseChangePlanner.isConfirmed(pending: pending, orders: [
            Self.leg(orderIndex: 700, clientOrderIndex: 7, kind: .takeProfit, price: 70000),
        ]))
        // Gone because canceled or because it fired — the reloaded orders are
        // the truth either way.
        XCTAssertTrue(PerpsAutoCloseChangePlanner.isConfirmed(pending: pending, orders: []))
        XCTAssertTrue(PerpsAutoCloseChangePlanner.isConfirmed(pending: pending, orders: [
            Self.leg(orderIndex: 9, kind: .stopLoss, price: 60000),
        ]))
    }

    func testUntouchedPrefillMatchesTheRestingLegsSoSetIsANoOp() {
        XCTAssertTrue(
            PerpsAutoCloseChangePlanner.matches(target: Self.autoClose(tp: nil, sl: nil), resting: []),
            "clearing legs that are already gone is a no-op, not an error"
        )
        let target = Self.autoClose(tp: 68141.70, sl: 64720.16)
        XCTAssertTrue(PerpsAutoCloseChangePlanner.matches(target: target, resting: [
            Self.leg(orderIndex: 1, kind: .takeProfit, price: 68141.70),
            Self.leg(orderIndex: 2, kind: .stopLoss, price: 64720.16),
        ]))
        XCTAssertFalse(
            PerpsAutoCloseChangePlanner.matches(target: target, resting: [
                Self.leg(orderIndex: 1, kind: .takeProfit, price: 68141.70),
            ]),
            "adding a missing SL leg is a real change"
        )
        XCTAssertFalse(
            PerpsAutoCloseChangePlanner.matches(
                target: Self.autoClose(tp: 68141.70, sl: nil),
                resting: [
                    Self.leg(orderIndex: 1, kind: .takeProfit, price: 68141.70),
                    Self.leg(orderIndex: 2, kind: .stopLoss, price: 64720.16),
                ]
            ),
            "clearing one resting leg is a real change"
        )
    }

    // MARK: - Review mapper

    func testReviewMapsRoundedSdkPricesAndPositionSide() {
        let review = PerpsAutoCloseChangeReviewMapper.map(
            review: LighterTpSlReview(
                marketId: 1,
                symbol: "BTC",
                side: LighterTradeSide.short_,
                baseAmount: 800,
                baseSize: 0.008,
                takeProfit: LighterAutoCloseReview(
                    kind: LighterOrderKind.market,
                    orderType: 0,
                    triggerPrice: 68141.7,
                    triggerPriceScaled: 6_814_170,
                    price: 68141.7,
                    priceScaled: 6_814_170,
                    clientOrderIndex: 11
                ),
                stopLoss: nil
            ),
            position: Self.makePosition(side: LighterTradeSide.long_)
        )
        XCTAssertEqual(review.side, .long, "side must come from the protected position, not the trigger order")
        XCTAssertEqual(review.new?.takeProfit?.triggerPrice, 68141.7)
        XCTAssertNil(review.new?.stopLoss)
    }

    func testCancelReviewClearsTarget() {
        let review = PerpsAutoCloseChangeReviewMapper.mapCancel(position: Self.makePosition(side: LighterTradeSide.long_))
        XCTAssertNil(review.new, "a cancel clears the target so the pending reconcile expects the legs gone")
    }

    // MARK: - Error mapping

    func testTypedSdkValidationErrorsMapWithoutParsingMessages() {
        XCTAssertEqual(
            PerpsTradingErrorMapper.map(
                kotlinError(
                    LighterValidationException(
                        message: "localized wording may change",
                        kind: LighterValidationKind.noPosition,
                        actualValue: nil,
                        limitValue: nil
                    )
                )
            ),
            .positionNotFound
        )
        XCTAssertEqual(
            PerpsTradingErrorMapper.map(
                kotlinError(
                    LighterValidationException(
                        message: "localized wording may change",
                        kind: LighterValidationKind.slippageBound,
                        actualValue: nil,
                        limitValue: nil
                    )
                )
            ),
            .insufficientLiquidity
        )
    }

    func testFailedOperationMapsTypedSdkCause() {
        let apiError = LighterApiException(
            message: "not enough collateral",
            cause: nil,
            kind: LighterErrorKind.serverRejected,
            httpStatus: nil,
            lighterCode: KotlinInt(value: LighterErrorCodes.shared.NOT_ENOUGH_COLLATERAL)
        )
        let operationError = LighterOperationException(
            operationId: "open-1",
            operationState: LighterOperationState.failed,
            cause: apiError
        )

        XCTAssertEqual(
            PerpsTradingErrorMapper.map(kotlinError(operationError)),
            .insufficientBalance
        )
    }

    private func kotlinError(_ exception: Any) -> Error {
        NSError(domain: "Kotlin", code: 0, userInfo: ["KotlinException": exception])
    }

    // MARK: - Fixtures

    private static func autoClose(tp: Double?, sl: Double?) -> PerpsAutoClose {
        PerpsAutoClose(
            takeProfit: tp.map { PerpsAutoCloseTrigger(triggerPrice: $0) },
            stopLoss: sl.map { PerpsAutoCloseTrigger(triggerPrice: $0) }
        )
    }

    private static func leg(
        orderIndex: Int64,
        clientOrderIndex: Int64 = 0,
        kind: PerpsTriggerOrderSummary.Kind,
        price: Double
    ) -> PerpsTriggerOrderSummary {
        PerpsTriggerOrderSummary(
            orderIndex: orderIndex,
            clientOrderIndex: clientOrderIndex,
            kind: kind,
            side: .short,
            triggerPrice: price,
            baseAmount: 0.008
        )
    }

    private static func makePosition(side: LighterTradeSide) -> LighterOpenPosition {
        LighterOpenPosition(
            marketId: 1,
            symbol: "BTC",
            side: side,
            size: 0.008,
            avgEntryPrice: 66000,
            allocatedMargin: 20,
            liquidationPrice: 64141.75,
            unrealizedPnl: 0.5,
            marginMode: 1,
            leverage: KotlinDouble(value: 27),
            fundingPaid: nil
        )
    }
}
