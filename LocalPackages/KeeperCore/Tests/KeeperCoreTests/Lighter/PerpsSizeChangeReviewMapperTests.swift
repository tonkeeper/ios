import ChainKit
@testable import KeeperCore
import XCTest

/// The size-change review blends the live position with the resizing order's
/// expected fill. These tests lock the non-obvious parts of that blend.
final class PerpsSizeChangeReviewMapperTests: XCTestCase {
    func testSideComesFromPositionNotResizingOrder() {
        let review = PerpsSizeChangeReviewMapper.map(
            direction: .reduce,
            review: Self.makeOrderReview(side: LighterTradeSide.short_),
            position: Self.makePosition(side: LighterTradeSide.long_),
            marginDeltaUsd: 10
        )
        XCTAssertEqual(review.side, .long)
    }

    func testAddUsesProjectedPositionWithoutBlendingEntryTwice() {
        let review = PerpsSizeChangeReviewMapper.map(
            direction: .add,
            review: Self.makeOrderReview(
                baseSize: 0.008,
                notionalUsd: 512,
                positionAfterBaseSize: 0.016,
                positionAfterEntryPrice: 65000
            ),
            position: Self.makePosition(size: 0.008, avgEntryPrice: 66000),
            marginDeltaUsd: 20
        )
        XCTAssertEqual(review.entryPrice.old, 66000)
        XCTAssertEqual(review.entryPrice.new, 65000, accuracy: 0.0001)
        XCTAssertEqual(review.notionalUsd.old, 528, accuracy: 0.0001)
        XCTAssertEqual(review.notionalUsd.new, 1040, accuracy: 0.0001)
    }

    func testReduceKeepsEntryAndShrinksNotionalOnEntryBasis() {
        let review = PerpsSizeChangeReviewMapper.map(
            direction: .reduce,
            review: Self.makeOrderReview(
                baseSize: 0.004,
                notionalUsd: 256,
                positionAfterBaseSize: 0.004,
                positionAfterEntryPrice: 66000
            ),
            position: Self.makePosition(size: 0.008, avgEntryPrice: 66000),
            marginDeltaUsd: 10
        )
        XCTAssertFalse(review.entryPrice.isChanged)
        XCTAssertEqual(review.notionalUsd.old, 528, accuracy: 0.0001)
        XCTAssertEqual(review.notionalUsd.new, 264, accuracy: 0.0001)
    }

    // MARK: - Fixtures

    private static func makeOrderReview(
        side: LighterTradeSide = LighterTradeSide.long_,
        baseSize: Double = 0.008,
        notionalUsd: Double = 512,
        positionAfterBaseSize: Double? = nil,
        positionAfterEntryPrice: Double? = nil
    ) -> LighterOrderReview {
        let positionAfter = positionAfterBaseSize.map { projectedSize in
            LighterPositionPreview(
                marketId: 1,
                side: side,
                baseAmount: 800,
                baseSize: projectedSize,
                entryPrice: positionAfterEntryPrice ?? 64000,
                liquidation: LighterLiquidationEstimate(
                    price: KotlinDouble(value: 64141.75),
                    isImmediateRisk: false,
                    unavailableReason: nil
                )
            )
        }
        return LighterOrderReview(
            marketId: 1,
            symbol: "BTC",
            side: side,
            kind: LighterOrderKind.market,
            reduceOnly: false,
            baseAmount: 800,
            baseSize: baseSize,
            price: 0,
            priceHuman: 64000,
            notionalUsd: notionalUsd,
            estimatedFeeUsd: KotlinDouble(value: 0.144),
            clientOrderIndex: 0,
            takeProfit: nil,
            stopLoss: nil,
            fillWorstPrice: nil,
            quoteFilled: nil,
            estimatedBaseFilled: nil,
            maintenanceMarginFraction: nil,
            estimatedPnlUsd: nil,
            estimatedReceiveUsd: nil,
            positionAfter: positionAfter
        )
    }

    private static func makePosition(
        side: LighterTradeSide = LighterTradeSide.long_,
        size: Double = 0.008,
        avgEntryPrice: Double = 66000
    ) -> LighterOpenPosition {
        LighterOpenPosition(
            marketId: 1,
            symbol: "BTC",
            side: side,
            size: size,
            avgEntryPrice: avgEntryPrice,
            allocatedMargin: 20,
            liquidationPrice: 64141.75,
            unrealizedPnl: 0.5,
            marginMode: 1,
            leverage: KotlinDouble(value: 27),
            fundingPaid: nil
        )
    }
}
